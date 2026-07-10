NexaPermissions = {
    core = nil,
    database = nil,
    registeredPermissions = {},
    rolesByName = {},
    adminDutyBySource = {}
}

local RESOURCE = GetCurrentResourceName()
local CONSOLE_ACTOR = {
    source = 0,
    accountId = 0,
    label = 'console'
}

local function encode(data)
    local ok, encoded = pcall(json.encode, data)
    return ok and encoded or '{}'
end

local function decode(value, fallback)
    if type(value) ~= 'string' or value == '' then
        return fallback
    end

    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or fallback
end

local function response(ok, code, message, data, meta)
    return {
        success = ok == true,
        ok = ok == true,
        code = code or (ok and 'OK' or 'INTERNAL_ERROR'),
        message = message or '',
        data = data,
        meta = meta,
        error = ok and nil or {
            code = code or 'INTERNAL_ERROR',
            message = message or 'Operation failed.'
        }
    }
end

local function log(level, category, message, context)
    local logger = NexaPermissions.core and NexaPermissions.core.Logger

    if logger and logger[level] then
        logger[level](category, message, context)
        return
    end

    print(('[%s] [%s] %s %s'):format(RESOURCE, level, message, context and encode(context) or ''))
end

local function getCore()
    if NexaPermissions.core then
        return NexaPermissions.core
    end

    local ok, core = pcall(function()
        return exports['nexa-core']:GetCoreObject()
    end)

    if ok and type(core) == 'table' then
        NexaPermissions.core = core
        NexaPermissions.database = core.Database
        return core
    end

    return nil
end

local function db()
    local core = getCore()
    return core and core.Database or nil
end

local function dbQuery(sql, params, options)
    local database = db()

    if not database or not database.Query then
        return nil, {
            code = 'DATABASE_UNAVAILABLE',
            message = 'Core database is unavailable.'
        }
    end

    return database.Query(sql, params or {}, options or {
        category = 'permissions.domain'
    })
end

local function dbSingle(sql, params, options)
    local database = db()

    if not database or not database.Single then
        return nil, {
            code = 'DATABASE_UNAVAILABLE',
            message = 'Core database is unavailable.'
        }
    end

    return database.Single(sql, params or {}, options or {
        category = 'permissions.domain'
    })
end

local function dbInsert(sql, params, options)
    local database = db()

    if not database or not database.Insert then
        return nil, {
            code = 'DATABASE_UNAVAILABLE',
            message = 'Core database is unavailable.'
        }
    end

    return database.Insert(sql, params or {}, options or {
        category = 'permissions.domain'
    })
end

local function dbUpdate(sql, params, options)
    local database = db()

    if not database or not database.Update then
        return nil, {
            code = 'DATABASE_UNAVAILABLE',
            message = 'Core database is unavailable.'
        }
    end

    return database.Update(sql, params or {}, options or {
        category = 'permissions.domain'
    })
end

local function dbDelete(sql, params, options)
    local database = db()

    if not database or not database.Delete then
        return nil, {
            code = 'DATABASE_UNAVAILABLE',
            message = 'Core database is unavailable.'
        }
    end

    return database.Delete(sql, params or {}, options or {
        category = 'permissions.domain'
    })
end

local function dbTransaction(queries, options)
    local database = db()

    if not database or not database.Transaction then
        return false, {
            code = 'DATABASE_UNAVAILABLE',
            message = 'Core database is unavailable.'
        }
    end

    return database.Transaction(queries, options or {
        category = 'permissions.domain.transaction'
    })
end

local function invalidate(subject)
    local core = getCore()

    if core and core.Permissions and core.Permissions.Invalidate then
        core.Permissions.Invalidate(subject)
    end
end

local function normalizeSubjectType(subjectType)
    if subjectType == 'account' or subjectType == 'character' then
        return subjectType
    end

    return nil
end

local function normalizeId(value)
    local id = tonumber(value)
    return id and id > 0 and id or nil
end

local function normalizeReason(reason)
    if type(reason) ~= 'string' then
        return nil
    end

    reason = reason:gsub('^%s+', ''):gsub('%s+$', '')

    if reason == '' then
        return nil
    end

    if #reason > 512 then
        reason = reason:sub(1, 512)
    end

    return reason
end

local function getAccountIdFromSource(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return nil
    end

    if GetResourceState('nexa_identity') == 'started' then
        local ok, accountId = pcall(function()
            return exports['nexa_identity']:GetAccountId(source)
        end)

        if ok and normalizeId(accountId) then
            return normalizeId(accountId)
        end
    end

    local core = getCore()

    if core and core.Players and core.Players.Get then
        local player = core.Players.Get(source)

        if player and normalizeId(player.id) then
            return normalizeId(player.id)
        end
    end

    return nil
end

local function resolveActor(actor)
    if actor == nil or actor == 0 then
        return CONSOLE_ACTOR
    end

    if type(actor) == 'number' or type(actor) == 'string' then
        local source = tonumber(actor)
        local accountId = getAccountIdFromSource(source)

        if not accountId then
            return nil, 'ACTOR_NOT_FOUND'
        end

        return {
            source = source,
            accountId = accountId,
            subject = {
                type = 'account',
                id = accountId,
                source = source
            }
        }
    end

    if type(actor) == 'table' then
        local source = tonumber(actor.source)
        local accountId = normalizeId(actor.accountId or actor.account_id or actor.id)

        if not accountId and source then
            accountId = getAccountIdFromSource(source)
        end

        if not accountId and source ~= 0 then
            return nil, 'ACTOR_NOT_FOUND'
        end

        return {
            source = source or 0,
            accountId = accountId or 0,
            label = actor.label,
            subject = accountId and accountId > 0 and {
                type = 'account',
                id = accountId,
                source = source
            } or nil
        }
    end

    return nil, 'ACTOR_NOT_FOUND'
end

local function resolveSubject(target)
    if type(target) == 'table' then
        local subjectType = normalizeSubjectType(target.subjectType or target.type)
        local subjectId = normalizeId(target.subjectId or target.id or target.accountId or target.characterId)

        if not subjectType and target.characterId then
            subjectType = 'character'
        end

        if not subjectType then
            subjectType = 'account'
        end

        if subjectType and subjectId then
            return {
                type = subjectType,
                id = subjectId,
                source = tonumber(target.source)
            }
        end
    end

    local source = tonumber(target)

    if source and source > 0 then
        local accountId = getAccountIdFromSource(source)

        if accountId then
            return {
                type = 'account',
                id = accountId,
                source = source
            }
        end
    end

    if NexaPermissionsIsIdentifier(target) then
        local row = dbSingle([[
            SELECT account_id
            FROM nexa_account_identifiers
            WHERE identifier = ?
            LIMIT 1
        ]], { target }, {
            category = 'permissions.resolve_identifier'
        })

        if row and normalizeId(row.account_id) then
            return {
                type = 'account',
                id = normalizeId(row.account_id)
            }
        end
    end

    return nil
end

local function roleLevel(roleName)
    roleName = NexaPermissionsNormalizeRoleName(roleName)
    return roleName and (NEXA_PERMISSIONS.roleLevels[roleName] or 0) or 0
end

local function hasPermission(actor, permission)
    if not actor then
        return false
    end

    if actor.source == 0 then
        return true
    end

    local core = getCore()

    if core and core.Permissions and core.Permissions.Has and actor.subject then
        return core.Permissions.Has(actor.subject, permission) == true
    end

    return false
end

local function getSubjectRoles(subject)
    local rows, err = dbQuery([[
        SELECT r.id, r.name, r.label
        FROM nexa_permission_subject_roles sr
        INNER JOIN nexa_permission_roles r ON r.id = sr.role_id
        WHERE sr.subject_type = ? AND sr.subject_id = ? AND r.enabled = 1
        ORDER BY r.name ASC
    ]], { subject.type, subject.id }, {
        category = 'permissions.subject_roles'
    })

    if err then
        return nil, err
    end

    local roles = {}

    for _, row in ipairs(rows or {}) do
        roles[#roles + 1] = {
            id = tonumber(row.id),
            name = row.name,
            label = row.label,
            level = roleLevel(row.name)
        }
    end

    return roles
end

local function highestRoleLevel(subject)
    local roles = getSubjectRoles(subject) or {}
    local highest = 0

    for _, role in ipairs(roles) do
        if role.level > highest then
            highest = role.level
        end
    end

    return highest
end

local function countOwners()
    local row = dbSingle([[
        SELECT COUNT(*) AS count
        FROM nexa_permission_subject_roles sr
        INNER JOIN nexa_permission_roles r ON r.id = sr.role_id
        WHERE sr.subject_type = 'account' AND r.name = 'owner'
    ]], {}, {
        category = 'permissions.owner_count'
    })

    return tonumber(row and row.count) or 0
end

local function audit(action, actor, target, payload)
    payload = payload or {}
    local metadata = payload.metadata or {}
    metadata.actorSource = actor and actor.source or nil
    metadata.target = target

    local _, err = dbInsert([[
        INSERT INTO nexa_permission_audit (
            action,
            actor_account_id,
            target_account_id,
            target_character_id,
            role_name,
            permission,
            old_value_json,
            new_value_json,
            reason,
            correlation_id,
            source_resource,
            result,
            metadata_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        action,
        actor and actor.accountId ~= 0 and actor.accountId or nil,
        target and target.type == 'account' and target.id or nil,
        target and target.type == 'character' and target.id or nil,
        payload.role,
        payload.permission,
        payload.oldValue and encode(payload.oldValue) or nil,
        payload.newValue and encode(payload.newValue) or nil,
        payload.reason,
        payload.correlationId,
        payload.sourceResource or GetInvokingResource() or RESOURCE,
        payload.result or 'success',
        encode(metadata)
    }, {
        category = 'permissions.audit'
    })

    if err then
        log('Error', 'permissions.audit', 'Permission audit write failed.', {
            action = action,
            code = err.code
        })
    end
end

local function protectedFailure(code, message, action, actor, target, payload)
    payload = payload or {}
    payload.result = 'denied'
    payload.reason = payload.reason or code
    audit(action or 'permission.denied', actor, target, payload)
    return response(false, code, message)
end

local function requireReason(reason, action, actor, target, payload)
    local normalized = normalizeReason(reason)

    if not normalized then
        return nil, protectedFailure('AUDIT_REASON_REQUIRED', 'Mutating permission actions require a reason.', action, actor, target, payload)
    end

    return normalized
end

local function requireActorPermission(actor, permission, action, target, payload)
    if hasPermission(actor, permission) then
        return true
    end

    return false, protectedFailure('ACTOR_NOT_AUTHORIZED', 'Actor is not authorized.', action, actor, target, payload)
end

local function canManageRole(actor, target, roleName, action)
    roleName = NexaPermissionsNormalizeRoleName(roleName)

    if not roleName then
        return false, 'ROLE_NOT_FOUND'
    end

    if actor.source == 0 then
        return true
    end

    local actorSubject = actor.subject
    local actorLevel = actorSubject and highestRoleLevel(actorSubject) or 0
    local targetLevel = roleLevel(roleName)

    if roleName == 'owner' and not hasPermission(actor, 'nexa.permissions.manage_owner') then
        return false, 'OWNER_PROTECTION'
    end

    if target and actor.accountId == target.id and target.type == 'account' and targetLevel > actorLevel then
        return false, 'SELF_ELEVATION_FORBIDDEN'
    end

    if targetLevel >= actorLevel and not hasPermission(actor, 'nexa.permissions.manage_owner') then
        return false, 'ROLE_HIERARCHY_FORBIDDEN'
    end

    if action == 'remove' and roleName == 'owner' and countOwners() <= 1 then
        return false, 'LAST_OWNER_PROTECTION'
    end

    return true
end

local function findRole(roleName)
    roleName = NexaPermissionsNormalizeRoleName(roleName)

    if not roleName then
        return nil
    end

    return NexaPermissions.rolesByName[roleName]
end

local function ensureRole(role)
    local roleName = NexaPermissionsNormalizeRoleName(role.name)

    if not roleName then
        return nil, 'INVALID_ROLE'
    end

    local existing = dbSingle([[
        SELECT id
        FROM nexa_permission_roles
        WHERE name = ?
        LIMIT 1
    ]], { roleName }, {
        category = 'permissions.ensure_role.lookup'
    })

    if existing and normalizeId(existing.id) then
        local _, updateErr = dbUpdate([[
            UPDATE nexa_permission_roles
            SET label = ?, description = ?, enabled = 1, updated_at = CURRENT_TIMESTAMP
            WHERE id = ?
        ]], { role.label or roleName, role.description, existing.id }, {
            category = 'permissions.ensure_role.update'
        })

        if updateErr then
            return nil, updateErr.code or 'DATABASE_ERROR'
        end

        return normalizeId(existing.id)
    end

    local roleId, insertErr = dbInsert([[
        INSERT INTO nexa_permission_roles (name, label, description, enabled)
        VALUES (?, ?, ?, 1)
    ]], { roleName, role.label or roleName, role.description }, {
        category = 'permissions.ensure_role.insert'
    })

    if insertErr then
        return nil, insertErr.code or 'DATABASE_ERROR'
    end

    return normalizeId(roleId)
end

local function ensurePermission(permission)
    local name = NexaPermissionsNormalizePermission(permission.name)

    if not name then
        return false, 'INVALID_PERMISSION'
    end

    local _, err = dbUpdate([[
        INSERT INTO nexa_registered_permissions (name, label, description, category, duty_required, critical, enabled)
        VALUES (?, ?, ?, ?, ?, ?, 1)
        ON DUPLICATE KEY UPDATE
            label = VALUES(label),
            description = VALUES(description),
            category = VALUES(category),
            duty_required = VALUES(duty_required),
            critical = VALUES(critical),
            enabled = VALUES(enabled),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        name,
        permission.label or name,
        permission.description,
        permission.category or 'general',
        permission.dutyRequired == true and 1 or 0,
        permission.critical == true and 1 or 0
    }, {
        category = 'permissions.ensure_permission'
    })

    if err then
        return false, err.code or 'DATABASE_ERROR'
    end

    return true
end

local function ensureRolePermission(roleId, permission, effect)
    local normalized = NexaPermissionsNormalizePermission(permission)

    if not roleId or not normalized then
        return false
    end

    local _, err = dbUpdate([[
        INSERT INTO nexa_permission_role_permissions (role_id, permission, effect)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE effect = VALUES(effect), updated_at = CURRENT_TIMESTAMP
    ]], { roleId, normalized, effect or 'allow' }, {
        category = 'permissions.ensure_role_permission'
    })

    return err == nil
end

local function ensureInheritance(roleId, inheritedRoleId)
    if not roleId or not inheritedRoleId then
        return true
    end

    local _, err = dbUpdate([[
        INSERT IGNORE INTO nexa_permission_role_inheritance (role_id, inherits_role_id)
        VALUES (?, ?)
    ]], { roleId, inheritedRoleId }, {
        category = 'permissions.ensure_role_inheritance'
    })

    return err == nil
end

local function refreshRoleCache()
    local rows, err = dbQuery([[
        SELECT id, name, label, description, enabled
        FROM nexa_permission_roles
        ORDER BY name ASC
    ]], {}, {
        category = 'permissions.roles.refresh'
    })

    if err then
        return false, err.code or 'DATABASE_ERROR'
    end

    NexaPermissions.rolesByName = {}

    for _, row in ipairs(rows or {}) do
        NexaPermissions.rolesByName[row.name] = {
            id = normalizeId(row.id),
            name = row.name,
            label = row.label,
            description = row.description,
            enabled = row.enabled == 1 or row.enabled == true,
            level = roleLevel(row.name)
        }
    end

    return true
end

local function refreshPermissionCatalog()
    local rows, err = dbQuery([[
        SELECT name, label, description, category, duty_required, critical, enabled
        FROM nexa_registered_permissions
        ORDER BY name ASC
    ]], {}, {
        category = 'permissions.catalog.refresh'
    })

    if err then
        return false, err.code or 'DATABASE_ERROR'
    end

    NexaPermissions.registeredPermissions = {}

    for _, row in ipairs(rows or {}) do
        NexaPermissions.registeredPermissions[row.name] = {
            name = row.name,
            label = row.label,
            description = row.description,
            category = row.category,
            dutyRequired = row.duty_required == 1 or row.duty_required == true,
            critical = row.critical == 1 or row.critical == true,
            enabled = row.enabled == 1 or row.enabled == true
        }
    end

    return true
end

local function syncSpecificSubjectTables(subject, roleName, permission, effect)
    if subject.type == 'account' and roleName then
        dbUpdate([[
            INSERT INTO nexa_account_roles (account_id, role_name)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP
        ]], { subject.id, roleName }, {
            category = 'permissions.account_roles.sync'
        })
    elseif subject.type == 'character' and roleName then
        dbUpdate([[
            INSERT INTO nexa_character_roles (character_id, role_name)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP
        ]], { subject.id, roleName }, {
            category = 'permissions.character_roles.sync'
        })
    end

    if subject.type == 'account' and permission and effect then
        dbUpdate([[
            INSERT INTO nexa_account_permissions (account_id, permission, effect)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE effect = VALUES(effect), updated_at = CURRENT_TIMESTAMP
        ]], { subject.id, permission, effect }, {
            category = 'permissions.account_permissions.sync'
        })
    elseif subject.type == 'character' and permission and effect then
        dbUpdate([[
            INSERT INTO nexa_character_permissions (character_id, permission, effect)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE effect = VALUES(effect), updated_at = CURRENT_TIMESTAMP
        ]], { subject.id, permission, effect }, {
            category = 'permissions.character_permissions.sync'
        })
    end
end

local function removeSpecificSubjectTables(subject, roleName, permission)
    if subject.type == 'account' and roleName then
        dbDelete('DELETE FROM nexa_account_roles WHERE account_id = ? AND role_name = ?', { subject.id, roleName }, {
            category = 'permissions.account_roles.remove'
        })
    elseif subject.type == 'character' and roleName then
        dbDelete('DELETE FROM nexa_character_roles WHERE character_id = ? AND role_name = ?', { subject.id, roleName }, {
            category = 'permissions.character_roles.remove'
        })
    end

    if subject.type == 'account' and permission then
        dbDelete('DELETE FROM nexa_account_permissions WHERE account_id = ? AND permission = ?', { subject.id, permission }, {
            category = 'permissions.account_permissions.remove'
        })
    elseif subject.type == 'character' and permission then
        dbDelete('DELETE FROM nexa_character_permissions WHERE character_id = ? AND permission = ?', { subject.id, permission }, {
            category = 'permissions.character_permissions.remove'
        })
    end
end

local function registerMigrations()
    local core = getCore()

    if not core or not core.Database or not core.Database.RegisterMigration then
        return false, 'DATABASE_UNAVAILABLE'
    end

    core.Database.RegisterMigration({
        id = '030_permission_domain',
        description = 'Create permission catalog, scoped role tables, audit and admin duty',
        transaction = false,
        statements = {
            [[
                CREATE TABLE IF NOT EXISTS nexa_registered_permissions (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    name VARCHAR(128) NOT NULL,
                    label VARCHAR(128) NOT NULL,
                    description TEXT NULL,
                    category VARCHAR(64) NOT NULL DEFAULT 'general',
                    duty_required TINYINT(1) NOT NULL DEFAULT 0,
                    critical TINYINT(1) NOT NULL DEFAULT 0,
                    enabled TINYINT(1) NOT NULL DEFAULT 1,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    UNIQUE KEY uq_nexa_registered_permissions_name (name),
                    KEY idx_nexa_registered_permissions_category (category),
                    KEY idx_nexa_registered_permissions_enabled (enabled)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]],
            [[
                CREATE TABLE IF NOT EXISTS nexa_account_roles (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    account_id BIGINT UNSIGNED NOT NULL,
                    role_name VARCHAR(64) NOT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    UNIQUE KEY uq_nexa_account_roles_account_role (account_id, role_name),
                    KEY idx_nexa_account_roles_account (account_id),
                    KEY idx_nexa_account_roles_role (role_name)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]],
            [[
                CREATE TABLE IF NOT EXISTS nexa_account_permissions (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    account_id BIGINT UNSIGNED NOT NULL,
                    permission VARCHAR(128) NOT NULL,
                    effect ENUM('allow', 'deny') NOT NULL DEFAULT 'allow',
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    UNIQUE KEY uq_nexa_account_permissions_account_permission (account_id, permission),
                    KEY idx_nexa_account_permissions_account (account_id),
                    KEY idx_nexa_account_permissions_permission (permission)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]],
            [[
                CREATE TABLE IF NOT EXISTS nexa_character_roles (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    character_id BIGINT UNSIGNED NOT NULL,
                    role_name VARCHAR(64) NOT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    UNIQUE KEY uq_nexa_character_roles_character_role (character_id, role_name),
                    KEY idx_nexa_character_roles_character (character_id),
                    KEY idx_nexa_character_roles_role (role_name)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]],
            [[
                CREATE TABLE IF NOT EXISTS nexa_character_permissions (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    character_id BIGINT UNSIGNED NOT NULL,
                    permission VARCHAR(128) NOT NULL,
                    effect ENUM('allow', 'deny') NOT NULL DEFAULT 'allow',
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    UNIQUE KEY uq_nexa_character_permissions_character_permission (character_id, permission),
                    KEY idx_nexa_character_permissions_character (character_id),
                    KEY idx_nexa_character_permissions_permission (permission)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]],
            [[
                CREATE TABLE IF NOT EXISTS nexa_permission_audit (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    action VARCHAR(96) NOT NULL,
                    actor_account_id BIGINT UNSIGNED NULL,
                    target_account_id BIGINT UNSIGNED NULL,
                    target_character_id BIGINT UNSIGNED NULL,
                    role_name VARCHAR(64) NULL,
                    permission VARCHAR(128) NULL,
                    old_value_json LONGTEXT NULL,
                    new_value_json LONGTEXT NULL,
                    reason VARCHAR(512) NOT NULL,
                    correlation_id VARCHAR(96) NULL,
                    source_resource VARCHAR(64) NOT NULL,
                    result VARCHAR(32) NOT NULL,
                    metadata_json LONGTEXT NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    KEY idx_nexa_permission_audit_action (action),
                    KEY idx_nexa_permission_audit_actor (actor_account_id),
                    KEY idx_nexa_permission_audit_target_account (target_account_id),
                    KEY idx_nexa_permission_audit_target_character (target_character_id),
                    KEY idx_nexa_permission_audit_role (role_name),
                    KEY idx_nexa_permission_audit_permission (permission),
                    KEY idx_nexa_permission_audit_created_at (created_at)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]],
            [[
                CREATE TABLE IF NOT EXISTS nexa_admin_duty (
                    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                    source INT NULL,
                    account_id BIGINT UNSIGNED NULL,
                    state ENUM('off_duty', 'on_duty', 'suspended') NOT NULL DEFAULT 'off_duty',
                    reason VARCHAR(512) NULL,
                    actor_account_id BIGINT UNSIGNED NULL,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    PRIMARY KEY (id),
                    UNIQUE KEY uq_nexa_admin_duty_account (account_id),
                    KEY idx_nexa_admin_duty_source (source),
                    KEY idx_nexa_admin_duty_state (state)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            ]]
        }
    })

    local ok, err = core.Database.RunMigrations()

    if not ok then
        return false, err and err.code or 'MIGRATION_FAILED'
    end

    return true
end

function NexaPermissions.RegisterPermission(permission, actor, reason)
    if type(permission) ~= 'table' then
        return response(false, 'PERMISSION_NOT_FOUND', 'Permission definition is invalid.')
    end

    local resolvedActor, actorErr = resolveActor(actor)
    local normalizedReason, reasonErr = requireReason(reason, 'permission.register', resolvedActor, nil, {
        permission = permission and permission.name
    })

    if reasonErr then
        return reasonErr
    end

    if not resolvedActor then
        return response(false, actorErr, 'Actor is invalid.')
    end

    local allowed, allowedErr = requireActorPermission(resolvedActor, 'nexa.permissions.grant', 'permission.register', nil, {
        permission = permission and permission.name,
        reason = normalizedReason
    })

    if not allowed then
        return allowedErr
    end

    local ok, err = ensurePermission(permission)

    if not ok then
        return response(false, err, 'Permission could not be registered.')
    end

    refreshPermissionCatalog()
    audit('permission.register', resolvedActor, nil, {
        permission = NexaPermissionsNormalizePermission(permission.name),
        reason = normalizedReason,
        newValue = permission
    })

    return response(true, 'OK', 'Permission registered.', permission)
end

function NexaPermissions.RegisterRole(role, actor, reason)
    if type(role) ~= 'table' then
        return response(false, 'ROLE_NOT_FOUND', 'Role definition is invalid.')
    end

    local resolvedActor, actorErr = resolveActor(actor)
    local normalizedReason, reasonErr = requireReason(reason, 'role.register', resolvedActor, nil, {
        role = role and role.name
    })

    if reasonErr then
        return reasonErr
    end

    if not resolvedActor then
        return response(false, actorErr, 'Actor is invalid.')
    end

    local allowed, allowedErr = requireActorPermission(resolvedActor, 'nexa.permissions.assign_role', 'role.register', nil, {
        role = role and role.name,
        reason = normalizedReason
    })

    if not allowed then
        return allowedErr
    end

    local roleId, err = ensureRole(role)

    if not roleId then
        return response(false, err, 'Role could not be registered.')
    end

    refreshRoleCache()
    invalidate(nil)
    audit('role.register', resolvedActor, nil, {
        role = NexaPermissionsNormalizeRoleName(role.name),
        reason = normalizedReason,
        newValue = role
    })

    return response(true, 'OK', 'Role registered.', findRole(role.name))
end

function NexaPermissions.SetRoleInheritance(roleName, inheritedRoleName, actor, reason)
    local resolvedActor, actorErr = resolveActor(actor)
    local normalizedReason, reasonErr = requireReason(reason, 'role.inheritance.set', resolvedActor, nil, {
        role = roleName
    })

    if reasonErr then
        return reasonErr
    end

    if not resolvedActor then
        return response(false, actorErr, 'Actor is invalid.')
    end

    local allowed, allowedErr = requireActorPermission(resolvedActor, 'nexa.permissions.assign_role', 'role.inheritance.set', nil, {
        role = roleName,
        reason = normalizedReason
    })

    if not allowed then
        return allowedErr
    end

    local role = findRole(roleName)
    local inherited = findRole(inheritedRoleName)

    if not role or not inherited then
        return response(false, 'ROLE_NOT_FOUND', 'Role does not exist.')
    end

    if role.name == inherited.name then
        return response(false, 'ROLE_INHERITANCE_CYCLE', 'Role cannot inherit itself.')
    end

    local ok = ensureInheritance(role.id, inherited.id)

    if not ok then
        return response(false, 'DATABASE_ERROR', 'Role inheritance could not be saved.')
    end

    invalidate(nil)
    audit('role.inheritance.set', resolvedActor, nil, {
        role = role.name,
        reason = normalizedReason,
        newValue = {
            inherits = inherited.name
        }
    })

    return response(true, 'OK', 'Role inheritance saved.')
end

function NexaPermissions.AssignRole(actorInput, targetInput, roleName, reason, options)
    local actor, actorErr = resolveActor(actorInput)
    local target = resolveSubject(targetInput)
    roleName = NexaPermissionsNormalizeRoleName(roleName)
    options = options or {}

    local normalizedReason, reasonErr = requireReason(reason, 'role.assign', actor, target, {
        role = roleName
    })

    if reasonErr then
        return reasonErr
    end

    if not actor then
        return response(false, actorErr, 'Actor is invalid.')
    end

    if not target then
        return response(false, 'TARGET_NOT_FOUND', 'Target subject was not found.')
    end

    local role = findRole(roleName)

    if not role then
        return response(false, 'ROLE_NOT_FOUND', 'Role does not exist.')
    end

    local allowed, allowedErr = requireActorPermission(actor, 'nexa.permissions.assign_role', 'role.assign', target, {
        role = roleName,
        reason = normalizedReason
    })

    if not allowed and not options.bootstrapOwner then
        return allowedErr
    end

    local manageable, manageErr = canManageRole(actor, target, roleName, 'assign')

    if not manageable and not options.bootstrapOwner then
        return protectedFailure(manageErr, 'Role hierarchy does not allow this assignment.', 'role.assign', actor, target, {
            role = roleName,
            reason = normalizedReason
        })
    end

    local existing = dbSingle([[
        SELECT id
        FROM nexa_permission_subject_roles
        WHERE subject_type = ? AND subject_id = ? AND role_id = ?
        LIMIT 1
    ]], { target.type, target.id, role.id }, {
        category = 'permissions.assign_role.existing'
    })

    if existing then
        return response(false, 'ROLE_ALREADY_ASSIGNED', 'Role is already assigned.')
    end

    local ok, txErr = dbTransaction({
        {
            query = [[
                INSERT INTO nexa_permission_subject_roles (subject_type, subject_id, role_id)
                VALUES (?, ?, ?)
            ]],
            params = { target.type, target.id, role.id }
        }
    }, {
        category = 'permissions.assign_role'
    })

    if not ok then
        return response(false, txErr and txErr.code or 'DATABASE_ERROR', 'Role could not be assigned.')
    end

    syncSpecificSubjectTables(target, roleName)
    invalidate(target)
    audit(options.bootstrapOwner and 'role.owner.bootstrap' or 'role.assign', actor, target, {
        role = roleName,
        reason = normalizedReason,
        newValue = {
            role = roleName
        },
        result = 'success'
    })

    return response(true, 'OK', 'Role assigned.', {
        subject = target,
        role = roleName
    })
end

function NexaPermissions.RemoveRole(actorInput, targetInput, roleName, reason)
    local actor, actorErr = resolveActor(actorInput)
    local target = resolveSubject(targetInput)
    roleName = NexaPermissionsNormalizeRoleName(roleName)
    local normalizedReason, reasonErr = requireReason(reason, 'role.remove', actor, target, {
        role = roleName
    })

    if reasonErr then
        return reasonErr
    end

    if not actor then
        return response(false, actorErr, 'Actor is invalid.')
    end

    if not target then
        return response(false, 'TARGET_NOT_FOUND', 'Target subject was not found.')
    end

    local role = findRole(roleName)

    if not role then
        return response(false, 'ROLE_NOT_FOUND', 'Role does not exist.')
    end

    local allowed, allowedErr = requireActorPermission(actor, 'nexa.permissions.remove_role', 'role.remove', target, {
        role = roleName,
        reason = normalizedReason
    })

    if not allowed then
        return allowedErr
    end

    local manageable, manageErr = canManageRole(actor, target, roleName, 'remove')

    if not manageable then
        return protectedFailure(manageErr, 'Role hierarchy does not allow this removal.', 'role.remove', actor, target, {
            role = roleName,
            reason = normalizedReason
        })
    end

    local removed, err = dbDelete([[
        DELETE FROM nexa_permission_subject_roles
        WHERE subject_type = ? AND subject_id = ? AND role_id = ?
    ]], { target.type, target.id, role.id }, {
        category = 'permissions.remove_role'
    })

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Role could not be removed.')
    end

    if tonumber(removed) == 0 then
        return response(false, 'ROLE_NOT_ASSIGNED', 'Role is not assigned.')
    end

    removeSpecificSubjectTables(target, roleName)
    invalidate(target)
    audit('role.remove', actor, target, {
        role = roleName,
        reason = normalizedReason,
        oldValue = {
            role = roleName
        },
        result = 'success'
    })

    return response(true, 'OK', 'Role removed.', {
        subject = target,
        role = roleName
    })
end

local function writePermission(actorInput, targetInput, permission, effect, reason)
    local actor, actorErr = resolveActor(actorInput)
    local target = resolveSubject(targetInput)
    local normalized = NexaPermissionsNormalizePermission(permission)
    local action = ('permission.%s'):format(effect)
    local normalizedReason, reasonErr = requireReason(reason, action, actor, target, {
        permission = normalized
    })

    if reasonErr then
        return reasonErr
    end

    if not actor then
        return response(false, actorErr, 'Actor is invalid.')
    end

    if not target then
        return response(false, 'TARGET_NOT_FOUND', 'Target subject was not found.')
    end

    if not normalized then
        return response(false, 'PERMISSION_NOT_FOUND', 'Permission is invalid.')
    end

    if not NexaPermissions.registeredPermissions[normalized] then
        return response(false, 'PERMISSION_NOT_FOUND', 'Permission is not registered.')
    end

    local requiredPermission = effect == 'deny' and 'nexa.permissions.deny' or 'nexa.permissions.grant'
    local allowed, allowedErr = requireActorPermission(actor, requiredPermission, action, target, {
        permission = normalized,
        reason = normalizedReason
    })

    if not allowed then
        return allowedErr
    end

    local existing = dbSingle([[
        SELECT effect
        FROM nexa_permission_subject_permissions
        WHERE subject_type = ? AND subject_id = ? AND permission = ?
        LIMIT 1
    ]], { target.type, target.id, normalized }, {
        category = 'permissions.permission.existing'
    })

    if existing and existing.effect == effect then
        return response(false, effect == 'allow' and 'PERMISSION_ALREADY_GRANTED' or 'PERMISSION_ALREADY_DENIED', 'Permission already has this effect.')
    end

    local _, err = dbUpdate([[
        INSERT INTO nexa_permission_subject_permissions (subject_type, subject_id, permission, effect)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE effect = VALUES(effect), updated_at = CURRENT_TIMESTAMP
    ]], { target.type, target.id, normalized, effect }, {
        category = 'permissions.permission.write'
    })

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Permission could not be saved.')
    end

    syncSpecificSubjectTables(target, nil, normalized, effect)
    invalidate(target)
    audit(action, actor, target, {
        permission = normalized,
        reason = normalizedReason,
        oldValue = existing,
        newValue = {
            effect = effect
        }
    })

    return response(true, 'OK', 'Permission saved.', {
        subject = target,
        permission = normalized,
        effect = effect
    })
end

function NexaPermissions.GrantPermission(actor, target, permission, reason)
    return writePermission(actor, target, permission, 'allow', reason)
end

function NexaPermissions.DenyPermission(actor, target, permission, reason)
    return writePermission(actor, target, permission, 'deny', reason)
end

function NexaPermissions.RevokePermission(actorInput, targetInput, permission, reason)
    local actor, actorErr = resolveActor(actorInput)
    local target = resolveSubject(targetInput)
    local normalized = NexaPermissionsNormalizePermission(permission)
    local normalizedReason, reasonErr = requireReason(reason, 'permission.revoke', actor, target, {
        permission = normalized
    })

    if reasonErr then
        return reasonErr
    end

    if not actor then
        return response(false, actorErr, 'Actor is invalid.')
    end

    if not target then
        return response(false, 'TARGET_NOT_FOUND', 'Target subject was not found.')
    end

    if not normalized then
        return response(false, 'PERMISSION_NOT_FOUND', 'Permission is invalid.')
    end

    local allowed, allowedErr = requireActorPermission(actor, 'nexa.permissions.revoke', 'permission.revoke', target, {
        permission = normalized,
        reason = normalizedReason
    })

    if not allowed then
        return allowedErr
    end

    local removed, err = dbDelete([[
        DELETE FROM nexa_permission_subject_permissions
        WHERE subject_type = ? AND subject_id = ? AND permission = ?
    ]], { target.type, target.id, normalized }, {
        category = 'permissions.permission.revoke'
    })

    if err then
        return response(false, err.code or 'DATABASE_ERROR', 'Permission could not be revoked.')
    end

    if tonumber(removed) == 0 then
        return response(false, 'PERMISSION_NOT_ASSIGNED', 'Permission is not assigned.')
    end

    removeSpecificSubjectTables(target, nil, normalized)
    invalidate(target)
    audit('permission.revoke', actor, target, {
        permission = normalized,
        reason = normalizedReason
    })

    return response(true, 'OK', 'Permission revoked.', {
        subject = target,
        permission = normalized
    })
end

function NexaPermissions.Has(source, permission)
    local normalized = NexaPermissionsNormalizePermission(permission)

    if not normalized or not NexaPermissions.registeredPermissions[normalized] then
        return response(true, 'OK', 'Permission checked.', {
            allowed = false,
            permission = normalized or permission,
            reason = 'PERMISSION_NOT_FOUND'
        })
    end

    local core = getCore()

    if not core or not core.Permissions then
        return response(false, 'CORE_UNAVAILABLE', 'Core permission engine is unavailable.')
    end

    local subject = resolveSubject(source)

    if not subject then
        return response(false, 'TARGET_NOT_FOUND', 'Permission subject was not found.')
    end

    local allowed = core.Permissions.Has(subject, normalized)

    return response(true, 'OK', 'Permission checked.', {
        allowed = allowed == true,
        permission = normalized,
        roles = getSubjectRoles(subject) or {}
    })
end

function NexaPermissions.HasAny(source, permissions)
    if type(permissions) ~= 'table' then
        return response(false, 'INVALID_INPUT', 'Permissions must be a table.')
    end

    for _, permission in ipairs(permissions) do
        local result = NexaPermissions.Has(source, permission)

        if result.ok and result.data.allowed then
            return response(true, 'OK', 'Permission checked.', {
                allowed = true,
                permission = result.data.permission
            })
        end
    end

    return response(true, 'OK', 'Permission checked.', {
        allowed = false
    })
end

function NexaPermissions.HasAll(source, permissions)
    if type(permissions) ~= 'table' then
        return response(false, 'INVALID_INPUT', 'Permissions must be a table.')
    end

    for _, permission in ipairs(permissions) do
        local result = NexaPermissions.Has(source, permission)

        if not result.ok then
            return result
        end

        if not result.data.allowed then
            return response(true, 'OK', 'Permission checked.', {
                allowed = false,
                missing = result.data.permission
            })
        end
    end

    return response(true, 'OK', 'Permission checked.', {
        allowed = true
    })
end

function NexaPermissions.GetRoles(target)
    local subject = resolveSubject(target)

    if not subject then
        return response(false, 'TARGET_NOT_FOUND', 'Subject was not found.')
    end

    return response(true, 'OK', 'Roles loaded.', getSubjectRoles(subject) or {})
end

function NexaPermissions.GetPermissions(target)
    local core = getCore()
    local subject = resolveSubject(target)

    if not subject then
        return response(false, 'TARGET_NOT_FOUND', 'Subject was not found.')
    end

    if not core or not core.Permissions or not core.Permissions.GetAll then
        return response(false, 'CORE_UNAVAILABLE', 'Core permission engine is unavailable.')
    end

    return core.Permissions.GetAll(subject)
end

function NexaPermissions.GetDecisionTrace(actorInput, targetInput, permission)
    local actor, actorErr = resolveActor(actorInput)
    local target = resolveSubject(targetInput)

    if not actor then
        return response(false, actorErr, 'Actor is invalid.')
    end

    if not target then
        return response(false, 'TARGET_NOT_FOUND', 'Subject was not found.')
    end

    if not hasPermission(actor, 'nexa.permissions.audit') then
        return response(false, 'ACTOR_NOT_AUTHORIZED', 'Actor is not authorized.')
    end

    local core = getCore()

    if not core or not core.Permissions or not core.Permissions.GetDecisionTrace then
        return response(false, 'CORE_UNAVAILABLE', 'Core permission engine is unavailable.')
    end

    return core.Permissions.GetDecisionTrace(target, permission)
end

function NexaPermissions.GetRole(roleName)
    local role = findRole(roleName)

    if not role then
        return response(false, 'ROLE_NOT_FOUND', 'Role does not exist.')
    end

    return response(true, 'OK', 'Role loaded.', role)
end

function NexaPermissions.ListRoles()
    local roles = {}

    for _, role in pairs(NexaPermissions.rolesByName) do
        roles[#roles + 1] = role
    end

    table.sort(roles, function(left, right)
        return left.name < right.name
    end)

    return response(true, 'OK', 'Roles loaded.', roles)
end

function NexaPermissions.ListRegisteredPermissions()
    local permissions = {}

    for _, permission in pairs(NexaPermissions.registeredPermissions) do
        permissions[#permissions + 1] = permission
    end

    table.sort(permissions, function(left, right)
        return left.name < right.name
    end)

    return response(true, 'OK', 'Permissions loaded.', permissions)
end

function NexaPermissions.GetPermissionCache(source)
    return NexaPermissions.GetPermissions(source)
end

function NexaPermissions.AssignRoleToPlayer(sourceOrIdentifier, roleName)
    return NexaPermissions.AssignRole(CONSOLE_ACTOR, sourceOrIdentifier, roleName, 'Legacy AssignRoleToPlayer compatibility export')
end

function NexaPermissions.RemoveRoleFromPlayer(sourceOrIdentifier, roleName)
    return NexaPermissions.RemoveRole(CONSOLE_ACTOR, sourceOrIdentifier, roleName, 'Legacy RemoveRoleFromPlayer compatibility export')
end

NexaPermissions.AdminDuty = {}

function NexaPermissions.AdminDuty.Set(source, state, actorInput, reason)
    source = tonumber(source)

    if not source or source <= 0 then
        return response(false, 'INVALID_SOURCE', 'Source is invalid.')
    end

    if not NEXA_PERMISSIONS.adminDutyStates[state] then
        return response(false, 'INVALID_INPUT', 'Duty state is invalid.')
    end

    local actor, actorErr = resolveActor(actorInput or source)
    local accountId = getAccountIdFromSource(source)

    if not actor then
        return response(false, actorErr, 'Actor is invalid.')
    end

    if not accountId then
        return response(false, 'TARGET_NOT_FOUND', 'Account was not found.')
    end

    if not hasPermission(actor, 'nexa.admin.duty') and actor.source ~= 0 then
        return response(false, 'ACTOR_NOT_AUTHORIZED', 'Actor is not authorized.')
    end

    local normalizedReason = normalizeReason(reason) or 'Admin duty state changed'
    NexaPermissions.adminDutyBySource[source] = {
        source = source,
        accountId = accountId,
        state = state,
        updatedAt = os.time()
    }

    dbUpdate([[
        INSERT INTO nexa_admin_duty (source, account_id, state, reason, actor_account_id)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            source = VALUES(source),
            state = VALUES(state),
            reason = VALUES(reason),
            actor_account_id = VALUES(actor_account_id),
            updated_at = CURRENT_TIMESTAMP
    ]], { source, accountId, state, normalizedReason, actor.accountId ~= 0 and actor.accountId or nil }, {
        category = 'permissions.admin_duty.set'
    })

    audit('admin_duty.set', actor, {
        type = 'account',
        id = accountId,
        source = source
    }, {
        reason = normalizedReason,
        newValue = {
            state = state
        }
    })

    return response(true, 'OK', 'Duty state saved.', NexaPermissions.adminDutyBySource[source])
end

function NexaPermissions.AdminDuty.Get(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return nil
    end

    return NexaPermissions.adminDutyBySource[source] or {
        source = source,
        state = 'off_duty'
    }
end

function NexaPermissions.AdminDuty.IsOnDuty(source)
    local duty = NexaPermissions.AdminDuty.Get(source)
    return duty and duty.state == 'on_duty'
end

function NexaPermissions.AdminDuty.Clear(source, reason)
    source = tonumber(source)

    if not source or source <= 0 then
        return response(false, 'INVALID_SOURCE', 'Source is invalid.')
    end

    local current = NexaPermissions.adminDutyBySource[source]
    NexaPermissions.adminDutyBySource[source] = nil

    dbUpdate([[
        UPDATE nexa_admin_duty
        SET state = 'off_duty', reason = ?, updated_at = CURRENT_TIMESTAMP
        WHERE source = ?
    ]], { normalizeReason(reason) or 'Duty cleared', source }, {
        category = 'permissions.admin_duty.clear'
    })

    audit('admin_duty.clear', CONSOLE_ACTOR, current and {
        type = 'account',
        id = current.accountId,
        source = source
    } or nil, {
        reason = normalizeReason(reason) or 'Duty cleared',
        oldValue = current
    })

    return response(true, 'OK', 'Duty cleared.')
end

local function seedCatalogAndRoles()
    for _, permission in ipairs(NEXA_PERMISSIONS.catalog) do
        local ok, err = ensurePermission(permission)

        if not ok then
            return false, err
        end
    end

    local roleIds = {}

    for _, role in ipairs(NEXA_PERMISSIONS.roles) do
        local roleId, err = ensureRole(role)

        if not roleId then
            return false, err
        end

        roleIds[role.name] = roleId
    end

    for _, role in ipairs(NEXA_PERMISSIONS.roles) do
        if role.inherits then
            if not ensureInheritance(roleIds[role.name], roleIds[role.inherits]) then
                return false, 'DATABASE_ERROR'
            end
        end
    end

    for roleName, permissions in pairs(NEXA_PERMISSIONS.rolePermissions) do
        for _, permission in ipairs(permissions) do
            if not ensureRolePermission(roleIds[roleName], permission, 'allow') then
                return false, 'DATABASE_ERROR'
            end
        end
    end

    refreshRoleCache()
    refreshPermissionCatalog()
    invalidate(nil)
    return true
end

function NexaPermissions.ReloadPermissions()
    local rolesOk, rolesErr = refreshRoleCache()

    if not rolesOk then
        return response(false, rolesErr, 'Roles could not be loaded.')
    end

    local catalogOk, catalogErr = refreshPermissionCatalog()

    if not catalogOk then
        return response(false, catalogErr, 'Permission catalog could not be loaded.')
    end

    invalidate(nil)
    return response(true, 'OK', 'Permissions reloaded.', {
        roles = NexaPermissions.rolesByName,
        permissionCount = #NEXA_PERMISSIONS.catalog
    })
end

function NexaPermissions.Start()
    local migrationOk, migrationErr = registerMigrations()

    if not migrationOk then
        log('Error', 'permissions.start', 'Permission migrations failed.', {
            error = migrationErr
        })
        return false
    end

    local seedOk, seedErr = seedCatalogAndRoles()

    if not seedOk then
        log('Error', 'permissions.start', 'Permission seed failed.', {
            error = seedErr
        })
        return false
    end

    log('Info', 'permissions.start', 'nexa_permissions started.', {
        roles = #NEXA_PERMISSIONS.roles,
        permissions = #NEXA_PERMISSIONS.catalog
    })

    return true
end
