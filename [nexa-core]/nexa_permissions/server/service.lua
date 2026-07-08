NexaPermissions = {
    rolesByName = {},
    rolesById = {},
    rulesByRoleId = {},
    cacheBySource = {},
    cacheByIdentifier = {}
}

local RESOURCE = GetCurrentResourceName()

local function encode(data)
    local ok, encoded = pcall(json.encode, data)
    return ok and encoded or '{}'
end

local function log(level, message, data)
    local logger = nil

    if GetResourceState('nexa-lib') == 'started' then
        local ok, exportedLogger = pcall(function()
            return exports['nexa-lib']:Logger()
        end)

        if ok and type(exportedLogger) == 'table' and type(exportedLogger[level]) == 'function' then
            logger = exportedLogger
        end
    end

    if logger then
        logger[level](RESOURCE, message, data)
        return
    end

    print(('[%s] [%s] %s %s'):format(RESOURCE, level, message, data and encode(data) or ''))
end

local function ok(data)
    return {
        ok = true,
        data = data,
        error = nil
    }
end

local function fail(code, message, details)
    return {
        ok = false,
        data = nil,
        error = {
            code = code or 'INTERNAL_ERROR',
            message = message or 'Operation failed.',
            details = details
        }
    }
end

local function dbQuery(query, params)
    local success, result = pcall(function()
        return MySQL.query.await(query, params or {})
    end)

    if not success then
        log('error', 'Database query failed.', {
            error = result
        })
        return nil, result
    end

    return result, nil
end

local function dbInsert(query, params)
    local success, result = pcall(function()
        return MySQL.insert.await(query, params or {})
    end)

    if not success then
        log('error', 'Database insert failed.', {
            error = result
        })
        return nil, result
    end

    return result, nil
end

local function dbUpdate(query, params)
    local success, result = pcall(function()
        return MySQL.update.await(query, params or {})
    end)

    if not success then
        log('error', 'Database update failed.', {
            error = result
        })
        return nil, result
    end

    return result, nil
end

local function callCoreExport(exportName, ...)
    local resourceExports = exports['nexa-core']

    if not resourceExports or type(resourceExports[exportName]) ~= 'function' then
        return nil
    end

    local args = { ... }
    local success, result = pcall(function()
        return resourceExports[exportName](resourceExports, table.unpack(args))
    end)

    if not success then
        log('error', 'Core export call failed.', {
            export = exportName,
            error = result
        })
        return nil
    end

    return result
end

local function getPlayer(source)
    return callCoreExport('GetPlayer', source)
end

local function getIdentifier(source)
    return callCoreExport('GetIdentifier', source)
end

local function getCharacter(source)
    return callCoreExport('GetCharacter', source)
end

local function getRoleByName(roleName)
    return NexaPermissions.rolesByName[NexaPermissionsNormalizeRoleName(roleName) or '']
end

local function clearCacheForSource(source)
    source = NexaPermissionsNormalizeSource(source)

    if not source then
        return
    end

    local identifier = getIdentifier(source)
    NexaPermissions.cacheBySource[source] = nil

    if identifier then
        NexaPermissions.cacheByIdentifier[identifier] = nil
    end
end

local function clearAllCaches()
    NexaPermissions.cacheBySource = {}
    NexaPermissions.cacheByIdentifier = {}
end

local function tableCount(values)
    local count = 0

    for _ in pairs(values or {}) do
        count = count + 1
    end

    return count
end

local function ensureRole(role)
    local name = NexaPermissionsNormalizeRoleName(role.name)

    if not name then
        return false, 'INVALID_ROLE'
    end

    local inherits = role.inherits and NexaPermissionsNormalizeRoleName(role.inherits) or nil
    local existingRows = dbQuery('SELECT id FROM nexa_permission_roles WHERE name = ? LIMIT 1', { name })

    if not existingRows then
        return false, 'DATABASE_ERROR'
    end

    if existingRows[1] then
        local updated = dbUpdate([[
            UPDATE nexa_permission_roles
            SET label = ?, priority = ?, inherits = ?, updated_at = CURRENT_TIMESTAMP
            WHERE name = ?
        ]], { role.label or name, tonumber(role.priority) or 0, inherits, name })

        return updated ~= nil, updated and nil or 'DATABASE_ERROR'
    end

    local inserted = dbInsert([[
        INSERT INTO nexa_permission_roles (name, label, priority, inherits)
        VALUES (?, ?, ?, ?)
    ]], { name, role.label or name, tonumber(role.priority) or 0, inherits })

    return inserted ~= nil, inserted and nil or 'DATABASE_ERROR'
end

local function ensureRoleRule(roleName, rule)
    local role = getRoleByName(roleName)

    if not role then
        return false, 'ROLE_NOT_FOUND'
    end

    local permission = NexaPermissionsNormalizePermission(rule.permission)

    if not permission then
        return false, 'INVALID_PERMISSION'
    end

    local allowed = rule.allowed ~= false
    local updated = dbUpdate([[
        INSERT INTO nexa_permission_role_rules (role_id, permission, allowed)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE allowed = VALUES(allowed)
    ]], { role.id, permission, allowed and 1 or 0 })

    return updated ~= nil, updated and nil or 'DATABASE_ERROR'
end

local function fetchRoles()
    local rows = dbQuery([[
        SELECT id, name, label, priority, inherits
        FROM nexa_permission_roles
        ORDER BY priority DESC, name ASC
    ]])

    if not rows then
        return false, 'DATABASE_ERROR'
    end

    NexaPermissions.rolesByName = {}
    NexaPermissions.rolesById = {}

    for _, row in ipairs(rows) do
        row.priority = tonumber(row.priority) or 0
        NexaPermissions.rolesByName[row.name] = row
        NexaPermissions.rolesById[tonumber(row.id)] = row
    end

    return true, nil
end

local function fetchRules()
    local rows = dbQuery([[
        SELECT role_id, permission, allowed
        FROM nexa_permission_role_rules
        ORDER BY id ASC
    ]])

    if not rows then
        return false, 'DATABASE_ERROR'
    end

    NexaPermissions.rulesByRoleId = {}

    for _, row in ipairs(rows) do
        local roleId = tonumber(row.role_id)
        NexaPermissions.rulesByRoleId[roleId] = NexaPermissions.rulesByRoleId[roleId] or {}
        NexaPermissions.rulesByRoleId[roleId][#NexaPermissions.rulesByRoleId[roleId] + 1] = {
            permission = row.permission,
            allowed = row.allowed == true or row.allowed == 1
        }
    end

    return true, nil
end

local function resolveInheritedRoles(role, resolved, visiting)
    if not role or resolved[role.name] then
        return
    end

    if visiting[role.name] then
        log('warn', 'Role inheritance cycle ignored.', {
            role = role.name
        })
        return
    end

    visiting[role.name] = true

    if role.inherits then
        resolveInheritedRoles(NexaPermissions.rolesByName[role.inherits], resolved, visiting)
    end

    resolved[role.name] = role
    visiting[role.name] = nil
end

local function fetchAssignments(player, identifier, character)
    local characterId = character and tonumber(character.id) or 0
    local rows = dbQuery([[
        SELECT DISTINCT r.id, r.name, r.label, r.priority, r.inherits
        FROM nexa_permission_assignments a
        INNER JOIN nexa_permission_roles r ON r.id = a.role_id
        WHERE
            (a.player_id IS NOT NULL AND a.player_id = ?)
            OR (a.identifier IS NOT NULL AND a.identifier = ?)
            OR (? > 0 AND a.character_id IS NOT NULL AND a.character_id = ?)
        ORDER BY r.priority DESC, r.name ASC
    ]], { player and player.id or 0, identifier or '', characterId, characterId })

    if not rows then
        return nil, 'DATABASE_ERROR'
    end

    return rows, nil
end

local function buildCache(source)
    source = NexaPermissionsNormalizeSource(source)

    if not source then
        return nil, 'INVALID_SOURCE'
    end

    local cached = NexaPermissions.cacheBySource[source]
    local now = os.time()

    if cached and cached.expiresAt > now then
        return cached, nil
    end

    local player = getPlayer(source)
    local identifier = getIdentifier(source)

    if not player or not identifier then
        return nil, 'PLAYER_NOT_FOUND'
    end

    local character = getCharacter(source)
    local assignedRoles, err = fetchAssignments(player, identifier, character)

    if err then
        return nil, err
    end

    local resolved = {}
    local defaultRole = getRoleByName(NexaPermissionsConfig.DefaultRole)

    if defaultRole then
        resolveInheritedRoles(defaultRole, resolved, {})
    end

    for _, role in ipairs(assignedRoles or {}) do
        role.priority = tonumber(role.priority) or 0
        resolveInheritedRoles(role, resolved, {})
    end

    local roles = {}
    local rules = {}

    for _, role in pairs(resolved) do
        roles[#roles + 1] = {
            id = role.id,
            name = role.name,
            label = role.label,
            priority = role.priority,
            inherits = role.inherits
        }

        for _, rule in ipairs(NexaPermissions.rulesByRoleId[tonumber(role.id)] or {}) do
            rules[#rules + 1] = {
                role = role.name,
                rolePriority = role.priority,
                permission = rule.permission,
                allowed = rule.allowed
            }
        end
    end

    table.sort(roles, function(a, b)
        if a.priority == b.priority then
            return a.name < b.name
        end

        return a.priority > b.priority
    end)

    table.sort(rules, function(a, b)
        if a.rolePriority == b.rolePriority then
            return #a.permission > #b.permission
        end

        return a.rolePriority > b.rolePriority
    end)

    local built = {
        source = source,
        playerId = player.id,
        identifier = identifier,
        characterId = character and character.id or nil,
        roles = roles,
        rules = rules,
        builtAt = now,
        expiresAt = now + NexaPermissionsServer.CacheTtlSeconds
    }

    NexaPermissions.cacheBySource[source] = built
    NexaPermissions.cacheByIdentifier[identifier] = built
    return built, nil
end

local function wildcardMatches(rulePermission, requestedPermission)
    if rulePermission == requestedPermission then
        return true, true
    end

    if rulePermission:sub(-2) ~= '.*' then
        return false, false
    end

    local prefix = rulePermission:sub(1, -2)
    return requestedPermission:sub(1, #prefix) == prefix, false
end

local function evaluate(cache, permission)
    local normalized = NexaPermissionsNormalizePermission(permission)

    if not normalized then
        return false, 'INVALID_PERMISSION', nil
    end

    if IsPlayerAceAllowed(cache.source, NexaPermissionsConfig.AcePrefix .. normalized) then
        return true, nil, {
            type = 'ace',
            permission = normalized
        }
    end

    local best = nil

    for _, rule in ipairs(cache.rules) do
        local matches, exact = wildcardMatches(rule.permission, normalized)

        if matches then
            local score = (rule.rolePriority * 10000) + (exact and 5000 or 0) + #rule.permission

            if not best or score > best.score then
                best = {
                    score = score,
                    rule = rule,
                    exact = exact
                }
            end
        end
    end

    if not best then
        return false, nil, nil
    end

    return best.rule.allowed == true, nil, best.rule
end

function NexaPermissions.Has(source, permission)
    local cache, err = buildCache(source)

    if err then
        return fail(err, 'Permission cache could not be built.', {
            source = source,
            permission = permission
        })
    end

    local allowed, permissionErr, rule = evaluate(cache, permission)

    if permissionErr then
        return fail(permissionErr, 'Permission input is invalid.', {
            permission = permission
        })
    end

    return ok({
        allowed = allowed,
        permission = NexaPermissionsNormalizePermission(permission),
        matchedRule = rule,
        roles = cache.roles
    })
end

function NexaPermissions.HasAny(source, permissions)
    if type(permissions) ~= 'table' then
        return fail('INVALID_INPUT', 'Permissions must be a list.')
    end

    for _, permission in ipairs(permissions) do
        local response = NexaPermissions.Has(source, permission)

        if response.ok and response.data.allowed then
            return ok({
                allowed = true,
                permission = response.data.permission,
                matchedRule = response.data.matchedRule
            })
        end
    end

    return ok({
        allowed = false
    })
end

function NexaPermissions.HasAll(source, permissions)
    if type(permissions) ~= 'table' then
        return fail('INVALID_INPUT', 'Permissions must be a list.')
    end

    for _, permission in ipairs(permissions) do
        local response = NexaPermissions.Has(source, permission)

        if not response.ok then
            return response
        end

        if not response.data.allowed then
            return ok({
                allowed = false,
                missing = response.data.permission
            })
        end
    end

    return ok({
        allowed = true
    })
end

function NexaPermissions.GetRoles(source)
    local cache, err = buildCache(source)

    if err then
        return fail(err, 'Roles could not be loaded.', {
            source = source
        })
    end

    return ok(cache.roles)
end

local function resolveAssignmentTarget(sourceOrIdentifier)
    local source = NexaPermissionsNormalizeSource(sourceOrIdentifier)

    if source then
        local player = getPlayer(source)
        local identifier = getIdentifier(source)

        if not player or not identifier then
            return nil, 'PLAYER_NOT_FOUND'
        end

        return {
            source = source,
            playerId = player.id,
            identifier = identifier
        }, nil
    end

    if NexaPermissionsIsIdentifier(sourceOrIdentifier) then
        return {
            source = nil,
            playerId = nil,
            identifier = sourceOrIdentifier
        }, nil
    end

    return nil, 'INVALID_INPUT'
end

function NexaPermissions.AssignRoleToPlayer(sourceOrIdentifier, roleName)
    local role = getRoleByName(roleName)

    if not role then
        return fail('ROLE_NOT_FOUND', 'Role does not exist.', {
            role = roleName
        })
    end

    local target, targetErr = resolveAssignmentTarget(sourceOrIdentifier)

    if targetErr then
        return fail(targetErr, 'Assignment target is invalid.', {
            target = sourceOrIdentifier
        })
    end

    local updated = dbUpdate([[
        INSERT INTO nexa_permission_assignments (player_id, identifier, role_id)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP
    ]], { target.playerId, target.identifier, role.id })

    if not updated then
        return fail('DATABASE_ERROR', 'Role assignment could not be saved.')
    end

    if target.source then
        clearCacheForSource(target.source)
    elseif target.identifier then
        NexaPermissions.cacheByIdentifier[target.identifier] = nil
    end

    return ok({
        assigned = true,
        role = role.name,
        target = target
    })
end

function NexaPermissions.RemoveRoleFromPlayer(sourceOrIdentifier, roleName)
    local role = getRoleByName(roleName)

    if not role then
        return fail('ROLE_NOT_FOUND', 'Role does not exist.', {
            role = roleName
        })
    end

    local target, targetErr = resolveAssignmentTarget(sourceOrIdentifier)

    if targetErr then
        return fail(targetErr, 'Assignment target is invalid.', {
            target = sourceOrIdentifier
        })
    end

    local updated = dbUpdate([[
        DELETE FROM nexa_permission_assignments
        WHERE role_id = ?
          AND ((player_id IS NOT NULL AND player_id = ?) OR (identifier IS NOT NULL AND identifier = ?))
    ]], { role.id, target.playerId or 0, target.identifier or '' })

    if not updated then
        return fail('DATABASE_ERROR', 'Role assignment could not be removed.')
    end

    if target.source then
        clearCacheForSource(target.source)
    elseif target.identifier then
        NexaPermissions.cacheByIdentifier[target.identifier] = nil
    end

    return ok({
        removed = updated > 0,
        role = role.name,
        target = target
    })
end

function NexaPermissions.ReloadPermissions()
    local rolesOk, rolesErr = fetchRoles()

    if not rolesOk then
        return fail(rolesErr, 'Roles could not be loaded.')
    end

    for _, role in ipairs(NexaPermissionsConfig.EnsureRoles or {}) do
        local ensured, ensureErr = ensureRole(role)

        if not ensured then
            return fail(ensureErr, 'Default role could not be ensured.', {
                role = role.name
            })
        end
    end

    rolesOk, rolesErr = fetchRoles()

    if not rolesOk then
        return fail(rolesErr, 'Roles could not be reloaded.')
    end

    for roleName, rules in pairs(NexaPermissionsConfig.DefaultRules or {}) do
        for _, rule in ipairs(rules) do
            local ensured, ensureErr = ensureRoleRule(roleName, rule)

            if not ensured then
                return fail(ensureErr, 'Default permission rule could not be ensured.', {
                    role = roleName,
                    permission = rule.permission
                })
            end
        end
    end

    local rulesOk, rulesErr = fetchRules()

    if not rulesOk then
        return fail(rulesErr, 'Permission rules could not be loaded.')
    end

    clearAllCaches()
    log('info', 'Permissions reloaded.', {
        roles = tableCount(NexaPermissions.rolesById)
    })

    return ok({
        reloaded = true
    })
end

function NexaPermissions.GetPermissionCache(source)
    local cache, err = buildCache(source)

    if err then
        return fail(err, 'Permission cache could not be loaded.', {
            source = source
        })
    end

    return ok(cache)
end

function NexaPermissions.Start()
    local response = NexaPermissions.ReloadPermissions()

    if not response.ok then
        log('error', 'nexa_permissions failed to start.', response.error)
        return false
    end

    log('info', 'nexa_permissions started.', {
        defaultRole = NexaPermissionsConfig.DefaultRole
    })

    return true
end
