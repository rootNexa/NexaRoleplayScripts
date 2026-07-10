Nexa.Permissions = Nexa.Permissions or {
    cache = {},
    roleCache = nil,
    traceCache = {}
}

local SUBJECT_TYPES = {
    account = true,
    character = true
}

local EFFECTS = {
    allow = true,
    deny = true
}

local PERMISSION_PATTERN = '^nexa%.[a-z0-9_%-]+%.[a-z0-9_%-%.%*]+$'

local function permissionLog(level, category, message, context)
    if Nexa.Logger and Nexa.Logger[level] then
        Nexa.Logger[level](category, message, context)
        return
    end

    Nexa.Log(level:lower(), message, context)
end

local function response(ok, code, message, data, meta)
    return {
        success = ok == true,
        code = code or (ok and 'OK' or 'INTERNAL_ERROR'),
        message = message or '',
        data = data,
        meta = meta
    }
end

local function normalizePermission(permission)
    if type(permission) ~= 'string' then
        return nil
    end

    permission = permission:lower():gsub('%s+', '')

    if permission == '' or #permission > 128 or not permission:match(PERMISSION_PATTERN) then
        return nil
    end

    if permission:find('%*') and not permission:match('%.%*$') then
        return nil
    end

    return permission
end

local function normalizeRole(role)
    if type(role) ~= 'string' then
        return nil
    end

    role = role:lower():gsub('%s+', '_'):gsub('[^a-z0-9_%-%.]', '')

    if role == '' or #role > 64 then
        return nil
    end

    return role
end

local function normalizeEffect(effect)
    if effect == true then
        return 'allow'
    end

    if effect == false then
        return 'deny'
    end

    if type(effect) ~= 'string' then
        return nil
    end

    effect = effect:lower()
    return EFFECTS[effect] and effect or nil
end

local function resolveSubject(subject)
    if type(subject) == 'table' then
        local subjectType = subject.subjectType or subject.type or subject.kind
        local subjectId = subject.subjectId or subject.id or subject.playerId or subject.characterId

        if subject.source then
            local player = Nexa.Players.Get(subject.source)

            if not player then
                return nil, 'SUBJECT_NOT_FOUND'
            end

            subjectType = subjectType or 'account'
            subjectId = subjectId or player.id
        end

        subjectId = tonumber(subjectId)

        if not SUBJECT_TYPES[subjectType] or not subjectId or subjectId <= 0 then
            return nil, 'INVALID_SUBJECT'
        end

        return {
            type = subjectType,
            id = subjectId,
            source = tonumber(subject.source)
        }, nil
    end

    local source = tonumber(subject)

    if source then
        local player = Nexa.Players.Get(source)

        if not player then
            return nil, 'SUBJECT_NOT_FOUND'
        end

        return {
            type = 'account',
            id = tonumber(player.id),
            source = source
        }, nil
    end

    return nil, 'INVALID_SUBJECT'
end

local function subjectKey(subject)
    return ('%s:%s'):format(subject.type, subject.id)
end

local function wildcardCandidates(permission)
    local candidates = { permission }
    local parts = {}

    for part in permission:gmatch('[^%.]+') do
        parts[#parts + 1] = part
    end

    for index = #parts - 1, 2, -1 do
        local wildcard = {}

        for i = 1, index do
            wildcard[#wildcard + 1] = parts[i]
        end

        wildcard[#wildcard + 1] = '*'
        candidates[#candidates + 1] = table.concat(wildcard, '.')
    end

    candidates[#candidates + 1] = 'nexa.*'
    return candidates
end

local function findRule(rules, permission)
    local candidates = wildcardCandidates(permission)

    for _, candidate in ipairs(candidates) do
        if rules[candidate] then
            return rules[candidate], candidate
        end
    end

    return nil, nil
end

local function audit(action, actor, context)
    if Nexa.Audit then
        Nexa.Audit(action, actor, context)
        return
    end

    permissionLog('Audit', 'permissions.audit', action, context)
end

local function invalidateRoleCache()
    Nexa.Permissions.roleCache = nil
end

local function loadRoles()
    if Nexa.Permissions.roleCache then
        return Nexa.Permissions.roleCache
    end

    local roleRows, roleErr = Nexa.Database.Query([[
        SELECT id, name, label, enabled
        FROM nexa_permission_roles
    ]], {}, {
        category = 'permissions.roles'
    })

    if roleErr then
        return nil, roleErr
    end

    local rolesById = {}
    local rolesByName = {}

    for _, row in ipairs(roleRows or {}) do
        local role = {
            id = tonumber(row.id),
            name = row.name,
            label = row.label,
            enabled = row.enabled == 1 or row.enabled == true,
            permissions = {},
            inherits = {}
        }

        rolesById[role.id] = role
        rolesByName[role.name] = role
    end

    local permissionRows, permissionErr = Nexa.Database.Query([[
        SELECT role_id, permission, effect
        FROM nexa_permission_role_permissions
    ]], {}, {
        category = 'permissions.role_permissions'
    })

    if permissionErr then
        return nil, permissionErr
    end

    for _, row in ipairs(permissionRows or {}) do
        local role = rolesById[tonumber(row.role_id)]

        if role and normalizePermission(row.permission) and EFFECTS[row.effect] then
            role.permissions[row.permission] = row.effect
        end
    end

    local inheritanceRows, inheritanceErr = Nexa.Database.Query([[
        SELECT role_id, inherits_role_id
        FROM nexa_permission_role_inheritance
    ]], {}, {
        category = 'permissions.role_inheritance'
    })

    if inheritanceErr then
        return nil, inheritanceErr
    end

    for _, row in ipairs(inheritanceRows or {}) do
        local role = rolesById[tonumber(row.role_id)]
        local inherited = rolesById[tonumber(row.inherits_role_id)]

        if role and inherited then
            role.inherits[#role.inherits + 1] = inherited.id
        end
    end

    Nexa.Permissions.roleCache = {
        byId = rolesById,
        byName = rolesByName
    }

    return Nexa.Permissions.roleCache, nil
end

local function collectRolePermissions(role, roles, output, trace, visiting)
    if not role or role.enabled ~= true then
        return true, nil
    end

    if visiting[role.id] then
        trace[#trace + 1] = {
            source = 'role_inheritance',
            role = role.name,
            decision = 'cycle_detected'
        }
        return false, 'ROLE_INHERITANCE_CYCLE'
    end

    visiting[role.id] = true

    for _, inheritedRoleId in ipairs(role.inherits) do
        local ok, err = collectRolePermissions(roles.byId[inheritedRoleId], roles, output, trace, visiting)

        if not ok then
            return false, err
        end
    end

    for permission, effect in pairs(role.permissions) do
        output[permission] = effect
        trace[#trace + 1] = {
            source = 'role',
            role = role.name,
            permission = permission,
            effect = effect
        }
    end

    visiting[role.id] = nil
    return true, nil
end

local function loadSubjectRules(subject)
    local roles, rolesErr = loadRoles()

    if not roles then
        return nil, rolesErr
    end

    local cache = {
        subject = subject,
        rules = {},
        roles = {},
        trace = {},
        loadedAt = os.time()
    }

    local subjectRoles, roleErr = Nexa.Database.Query([[
        SELECT r.id, r.name
        FROM nexa_permission_subject_roles sr
        INNER JOIN nexa_permission_roles r ON r.id = sr.role_id
        WHERE sr.subject_type = ? AND sr.subject_id = ? AND r.enabled = 1
    ]], { subject.type, subject.id }, {
        category = 'permissions.subject_roles'
    })

    if roleErr then
        return nil, roleErr
    end

    for _, row in ipairs(subjectRoles or {}) do
        local role = roles.byId[tonumber(row.id)]

        if role then
            cache.roles[#cache.roles + 1] = role.name
            local ok, err = collectRolePermissions(role, roles, cache.rules, cache.trace, {})

            if not ok then
                return nil, {
                    code = err,
                    message = 'Rollenvererbung ist ungueltig.'
                }
            end
        end
    end

    local directRows, directErr = Nexa.Database.Query([[
        SELECT permission, effect
        FROM nexa_permission_subject_permissions
        WHERE subject_type = ? AND subject_id = ?
    ]], { subject.type, subject.id }, {
        category = 'permissions.subject_permissions'
    })

    if directErr then
        return nil, directErr
    end

    for _, row in ipairs(directRows or {}) do
        local permission = normalizePermission(row.permission)

        if permission and EFFECTS[row.effect] then
            cache.rules[permission] = row.effect
            cache.trace[#cache.trace + 1] = {
                source = 'direct',
                permission = permission,
                effect = row.effect
            }
        end
    end

    if subject.type == 'account' then
        local legacyRows, legacyErr = Nexa.Database.Query([[
            SELECT permission, value
            FROM nexa_permissions
            WHERE player_id = ?
        ]], { subject.id }, {
            category = 'permissions.legacy'
        })

        if not legacyErr then
            for _, row in ipairs(legacyRows or {}) do
                local permission = normalizePermission(row.permission)

                if permission then
                    local effect = (row.value == 1 or row.value == true) and 'allow' or 'deny'
                    cache.rules[permission] = effect
                    cache.trace[#cache.trace + 1] = {
                        source = 'legacy',
                        permission = permission,
                        effect = effect
                    }
                end
            end
        end
    end

    return cache, nil
end

local function getCached(subject)
    local key = subjectKey(subject)
    local cached = Nexa.Permissions.cache[key]

    if cached then
        return cached, nil
    end

    local loaded, err = loadSubjectRules(subject)

    if not loaded then
        return nil, err
    end

    Nexa.Permissions.cache[key] = loaded
    return loaded, nil
end

local function aceAllows(subject, permission)
    if not subject.source or not IsPlayerAceAllowed then
        return false, nil
    end

    if IsPlayerAceAllowed(subject.source, permission) then
        return true, permission
    end

    local aceName = ('nexa.%s'):format(permission)

    if IsPlayerAceAllowed(subject.source, aceName) then
        return true, aceName
    end

    return false, nil
end

local function decide(subject, permission)
    local normalized = normalizePermission(permission)
    local trace = {
        subject = subject,
        permission = normalized or permission,
        steps = {},
        result = false,
        reason = nil
    }

    if not normalized then
        trace.reason = 'INVALID_PERMISSION'
        return false, trace
    end

    local cached, err = getCached(subject)

    if not cached then
        trace.reason = err and err.code or 'LOAD_FAILED'
        trace.error = err
        return false, trace
    end

    for _, step in ipairs(cached.trace) do
        trace.steps[#trace.steps + 1] = step
    end

    local denyRules = {}
    local allowRules = {}

    for rule, effect in pairs(cached.rules) do
        if effect == 'deny' then
            denyRules[rule] = effect
        elseif effect == 'allow' then
            allowRules[rule] = effect
        end
    end

    local denyEffect, denyMatch = findRule(denyRules, normalized)

    if denyEffect == 'deny' then
        trace.result = false
        trace.reason = 'EXPLICIT_DENY'
        trace.matchedPermission = denyMatch
        return false, trace
    end

    local allowEffect, allowMatch = findRule(allowRules, normalized)

    if allowEffect == 'allow' then
        trace.result = true
        trace.reason = 'ALLOW'
        trace.matchedPermission = allowMatch
        return true, trace
    end

    local aceAllowed, acePermission = aceAllows(subject, normalized)

    if aceAllowed then
        trace.result = true
        trace.reason = 'ACE_FALLBACK'
        trace.matchedPermission = acePermission
        return true, trace
    end

    trace.result = false
    trace.reason = 'NO_MATCH'
    return false, trace
end

local function ensureRole(roleName, label)
    roleName = normalizeRole(roleName)

    if not roleName then
        return nil, 'INVALID_ROLE'
    end

    local role, lookupErr = Nexa.Database.Single([[
        SELECT id, name
        FROM nexa_permission_roles
        WHERE name = ?
        LIMIT 1
    ]], { roleName }, {
        category = 'permissions.role_lookup'
    })

    if lookupErr then
        return nil, 'DATABASE_ERROR'
    end

    if role then
        return tonumber(role.id), nil
    end

    local roleId, err = Nexa.Database.Insert([[
        INSERT INTO nexa_permission_roles (name, label)
        VALUES (?, ?)
    ]], { roleName, label or roleName }, {
        category = 'permissions.role_create'
    })

    if err then
        return nil, 'DATABASE_ERROR'
    end

    invalidateRoleCache()
    return tonumber(roleId), nil
end

local function writeSubjectPermission(subject, permission, effect, actor)
    local normalized = normalizePermission(permission)
    effect = normalizeEffect(effect)

    if not normalized or not effect then
        return response(false, 'INVALID_INPUT', 'Permission oder Effekt ist ungueltig.')
    end

    local _, err = Nexa.Database.Update([[
        INSERT INTO nexa_permission_subject_permissions (subject_type, subject_id, permission, effect)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE effect = VALUES(effect), updated_at = CURRENT_TIMESTAMP
    ]], { subject.type, subject.id, normalized, effect }, {
        category = 'permissions.subject_permission_write'
    })

    if err then
        return response(false, 'DATABASE_ERROR', 'Permission konnte nicht gespeichert werden.')
    end

    Nexa.Permissions.Invalidate(subject)
    audit(('permission.%s'):format(effect), actor, {
        subject = subject,
        permission = normalized
    })

    return response(true, 'OK', 'Permission gespeichert.', {
        subject = subject,
        permission = normalized,
        effect = effect
    })
end

function Nexa.Permissions.Load(subject)
    local resolved, subjectErr = resolveSubject(subject)

    if not resolved then
        return {}
    end

    local loaded, err = getCached(resolved)

    if not loaded then
        permissionLog('Error', 'permissions.load', 'Permissions konnten nicht geladen werden.', {
            subject = resolved,
            error = err
        })
        return {}
    end

    return loaded.rules
end

function Nexa.Permissions.Has(subject, permission, context)
    local resolved, subjectErr = resolveSubject(subject)

    if not resolved then
        return false
    end

    local allowed, trace = decide(resolved, permission)
    Nexa.Permissions.traceCache[('%s:%s'):format(subjectKey(resolved), tostring(permission))] = trace

    if context and context.audit == true then
        audit('permission.check', context.actor or resolved.source, {
            subject = resolved,
            permission = permission,
            allowed = allowed,
            reason = trace.reason
        })
    end

    return allowed
end

function Nexa.Permissions.GetAll(subject)
    local resolved, subjectErr = resolveSubject(subject)

    if not resolved then
        return response(false, subjectErr, 'Subjekt ist ungueltig.')
    end

    local cached, err = getCached(resolved)

    if not cached then
        return response(false, err and err.code or 'LOAD_FAILED', 'Permissions konnten nicht geladen werden.')
    end

    return response(true, 'OK', 'Permissions geladen.', {
        subject = resolved,
        roles = cached.roles,
        permissions = cached.rules
    })
end

function Nexa.Permissions.AssignRole(subject, role)
    local resolved, subjectErr = resolveSubject(subject)
    local roleId, roleErr = ensureRole(role)

    if not resolved or not roleId then
        return response(false, subjectErr or roleErr, 'Rolle konnte nicht zugewiesen werden.')
    end

    local _, err = Nexa.Database.Update([[
        INSERT INTO nexa_permission_subject_roles (subject_type, subject_id, role_id)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP
    ]], { resolved.type, resolved.id, roleId }, {
        category = 'permissions.assign_role'
    })

    if err then
        return response(false, 'DATABASE_ERROR', 'Rolle konnte nicht gespeichert werden.')
    end

    Nexa.Permissions.Invalidate(resolved)
    audit('permission.role.assign', resolved.source, {
        subject = resolved,
        role = normalizeRole(role)
    })

    return response(true, 'OK', 'Rolle zugewiesen.')
end

function Nexa.Permissions.RemoveRole(subject, role)
    local resolved, subjectErr = resolveSubject(subject)
    role = normalizeRole(role)

    if not resolved or not role then
        return response(false, subjectErr or 'INVALID_ROLE', 'Rolle konnte nicht entfernt werden.')
    end

    local _, err = Nexa.Database.Delete([[
        DELETE sr
        FROM nexa_permission_subject_roles sr
        INNER JOIN nexa_permission_roles r ON r.id = sr.role_id
        WHERE sr.subject_type = ? AND sr.subject_id = ? AND r.name = ?
    ]], { resolved.type, resolved.id, role }, {
        category = 'permissions.remove_role'
    })

    if err then
        return response(false, 'DATABASE_ERROR', 'Rolle konnte nicht entfernt werden.')
    end

    Nexa.Permissions.Invalidate(resolved)
    audit('permission.role.remove', resolved.source, {
        subject = resolved,
        role = role
    })

    return response(true, 'OK', 'Rolle entfernt.')
end

function Nexa.Permissions.Grant(subject, permission)
    local resolved, subjectErr = resolveSubject(subject)

    if not resolved then
        return response(false, subjectErr, 'Subjekt ist ungueltig.')
    end

    return writeSubjectPermission(resolved, permission, 'allow', resolved.source)
end

function Nexa.Permissions.Deny(subject, permission)
    local resolved, subjectErr = resolveSubject(subject)

    if not resolved then
        return response(false, subjectErr, 'Subjekt ist ungueltig.')
    end

    return writeSubjectPermission(resolved, permission, 'deny', resolved.source)
end

function Nexa.Permissions.Revoke(subject, permission)
    local resolved, subjectErr = resolveSubject(subject)
    local normalized = normalizePermission(permission)

    if not resolved or not normalized then
        return response(false, subjectErr or 'INVALID_PERMISSION', 'Permission konnte nicht entfernt werden.')
    end

    local _, err = Nexa.Database.Delete([[
        DELETE FROM nexa_permission_subject_permissions
        WHERE subject_type = ? AND subject_id = ? AND permission = ?
    ]], { resolved.type, resolved.id, normalized }, {
        category = 'permissions.revoke'
    })

    if err then
        return response(false, 'DATABASE_ERROR', 'Permission konnte nicht entfernt werden.')
    end

    Nexa.Permissions.Invalidate(resolved)
    audit('permission.revoke', resolved.source, {
        subject = resolved,
        permission = normalized
    })

    return response(true, 'OK', 'Permission entfernt.')
end

function Nexa.Permissions.Invalidate(subject)
    if subject == nil then
        Nexa.Permissions.cache = {}
        Nexa.Permissions.traceCache = {}
        invalidateRoleCache()
        return true
    end

    local resolved = type(subject) == 'table' and subject or select(1, resolveSubject(subject))

    if not resolved or not resolved.type or not resolved.id then
        return false
    end

    Nexa.Permissions.cache[subjectKey(resolved)] = nil

    for key in pairs(Nexa.Permissions.traceCache) do
        if key:find(subjectKey(resolved), 1, true) == 1 then
            Nexa.Permissions.traceCache[key] = nil
        end
    end

    return true
end

function Nexa.Permissions.GetDecisionTrace(subject, permission)
    local resolved, subjectErr = resolveSubject(subject)

    if not resolved then
        return response(false, subjectErr, 'Subjekt ist ungueltig.')
    end

    local allowed, trace = decide(resolved, permission)
    return response(true, 'OK', 'Permission-Entscheidung geladen.', {
        allowed = allowed,
        trace = trace
    })
end

function Nexa.Permissions.Set(playerId, permission, value, actor)
    local subject = {
        type = 'account',
        id = tonumber(playerId),
        source = tonumber(actor)
    }

    if not subject.id or type(value) ~= 'boolean' then
        return false, 'INVALID_INPUT'
    end

    local result = writeSubjectPermission(subject, permission, value and 'allow' or 'deny', actor)
    return result.success == true, result.success and nil or result.code
end

Nexa.Database.RegisterMigration({
    id = '002_permission_foundation',
    description = 'Create core permission role foundation tables',
    transaction = false,
    statements = {
        [[
            CREATE TABLE IF NOT EXISTS nexa_permission_roles (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                name VARCHAR(64) NOT NULL,
                label VARCHAR(128) NOT NULL,
                description TEXT NULL,
                enabled TINYINT(1) NOT NULL DEFAULT 1,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_nexa_permission_roles_name (name),
                KEY idx_nexa_permission_roles_enabled (enabled)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS nexa_permission_role_permissions (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                role_id BIGINT UNSIGNED NOT NULL,
                permission VARCHAR(128) NOT NULL,
                effect ENUM('allow', 'deny') NOT NULL DEFAULT 'allow',
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_nexa_permission_role_permission (role_id, permission),
                KEY idx_nexa_permission_role_permissions_permission (permission),
                CONSTRAINT fk_nexa_permission_role_permissions_role
                    FOREIGN KEY (role_id) REFERENCES nexa_permission_roles (id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS nexa_permission_role_inheritance (
                role_id BIGINT UNSIGNED NOT NULL,
                inherits_role_id BIGINT UNSIGNED NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (role_id, inherits_role_id),
                KEY idx_nexa_permission_role_inheritance_parent (inherits_role_id),
                CONSTRAINT fk_nexa_permission_role_inheritance_role
                    FOREIGN KEY (role_id) REFERENCES nexa_permission_roles (id)
                    ON DELETE CASCADE,
                CONSTRAINT fk_nexa_permission_role_inheritance_parent
                    FOREIGN KEY (inherits_role_id) REFERENCES nexa_permission_roles (id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS nexa_permission_subject_roles (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                subject_type ENUM('account', 'character') NOT NULL,
                subject_id BIGINT UNSIGNED NOT NULL,
                role_id BIGINT UNSIGNED NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_nexa_permission_subject_role (subject_type, subject_id, role_id),
                KEY idx_nexa_permission_subject_roles_subject (subject_type, subject_id),
                CONSTRAINT fk_nexa_permission_subject_roles_role
                    FOREIGN KEY (role_id) REFERENCES nexa_permission_roles (id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]],
        [[
            CREATE TABLE IF NOT EXISTS nexa_permission_subject_permissions (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                subject_type ENUM('account', 'character') NOT NULL,
                subject_id BIGINT UNSIGNED NOT NULL,
                permission VARCHAR(128) NOT NULL,
                effect ENUM('allow', 'deny') NOT NULL DEFAULT 'allow',
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_nexa_permission_subject_permission (subject_type, subject_id, permission),
                KEY idx_nexa_permission_subject_permissions_subject (subject_type, subject_id),
                KEY idx_nexa_permission_subject_permissions_permission (permission)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        ]]
    }
})
