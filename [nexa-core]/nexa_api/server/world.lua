local worldLimits = {
    maxNameLength = 28,
    maxResourceNameLength = 28,
    maxValueLength = 4000,
    maxStates = 100,
    maxResources = 50
}

local worldPermissions = {
    read = 'world.state.read',
    manage = 'world.state.manage'
}

local allowedScopes = {
    global = true,
    resource = true
}

local function respond(success, code, message, data, meta, auditId)
    return NexaApiResponse(success, code, message, data, meta, auditId)
end

local function normalizeText(value, fallback, maxLength)
    if value == nil then
        return fallback
    end

    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return fallback
    end

    if maxLength ~= nil and #trimmed > maxLength then
        return nil
    end

    return trimmed
end

local function normalizeName(value, maxLength)
    local name = normalizeText(value, nil, maxLength)

    if name == nil or name:match('^[%w_.:-]+$') == nil then
        return nil
    end

    return name
end

local function normalizeScope(value)
    local scope = normalizeText(value, 'global', 32)

    if scope == nil then
        return nil
    end

    scope = scope:lower()

    if not allowedScopes[scope] then
        return nil
    end

    return scope
end

local function encodeJson(value)
    local ok, encoded = pcall(json.encode, value)

    if not ok or encoded == nil or #encoded > worldLimits.maxValueLength then
        return nil
    end

    return encoded
end

local function decodeJson(value)
    if value == nil or value == '' then
        return nil
    end

    local ok, decoded = pcall(json.decode, value)

    if not ok then
        return nil
    end

    return decoded
end

local function getActor(source)
    if source == nil or tonumber(source) == 0 then
        return nil, 'OK'
    end

    local active = getActiveCharacter(source)

    if active == nil or not active.success or active.data == nil or active.data.character == nil then
        return nil, 'CHARACTER_NOT_LOADED'
    end

    return active.data.character, 'OK'
end

local function getInvokingResourceName()
    return GetInvokingResource() or NEXA_API.resourceName
end

local function ensureWorldCaller()
    local caller = getInvokingResourceName()

    return caller == 'nexa_worldstates' or caller == NEXA_API.resourceName
end

local function hasWorldPermission(source, permission)
    if source == nil or tonumber(source) == 0 then
        return true
    end

    local result = exports.nexa_permissions:has(source, permission)

    return result == true or (type(result) == 'table' and result.success == true)
end

local function ensureWorldAccess(source, permission)
    if not ensureWorldCaller() then
        return false, 'NO_PERMISSION', 'Diese Resource darf keine World States verwalten.'
    end

    if not hasWorldPermission(source, permission) then
        return false, 'NO_PERMISSION', 'Du hast dafuer keine World-State-Berechtigung.'
    end

    return true, 'OK', 'OK'
end

local function writeWorldAudit(action, actor, targetId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'world',
        severity = 'info',
        actorPlayerId = actor and actor.player_id or nil,
        actorCharacterId = actor and actor.id or nil,
        targetType = 'world_state',
        targetId = targetId,
        action = action,
        resourceName = NEXA_API.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function buildStateKey(scope, stateName, resourceName)
    if scope == 'resource' then
        return ('ws.r.%s.%s'):format(resourceName, stateName)
    end

    return ('ws.g.%s'):format(stateName)
end

local function normalizeStatePayload(payload, requireValue)
    if type(payload) ~= 'table' then
        return nil
    end

    local scope = normalizeScope(payload.scope)
    local stateName = normalizeName(payload.stateName or payload.name, worldLimits.maxNameLength)
    local resourceName = nil

    if scope == 'resource' then
        resourceName = normalizeName(payload.resourceName, worldLimits.maxResourceNameLength)

        if resourceName == nil then
            return nil
        end
    end

    if scope == nil or stateName == nil then
        return nil
    end

    local encodedValue = nil

    if requireValue then
        if payload.value == nil then
            return nil
        end

        encodedValue = encodeJson(payload.value)

        if encodedValue == nil then
            return nil
        end
    end

    return {
        scope = scope,
        stateName = stateName,
        resourceName = resourceName,
        settingKey = buildStateKey(scope, stateName, resourceName),
        value = payload.value,
        encodedValue = encodedValue,
        ttlSeconds = tonumber(payload.ttlSeconds),
        metadata = type(payload.metadata) == 'table' and payload.metadata or {}
    }
end

local function mapState(row)
    if row == nil then
        return nil
    end

    local container = decodeJson(row.setting_value) or {}
    local metadata = type(container.metadata) == 'table' and container.metadata or {}

    return {
        key = row.setting_key,
        scope = metadata.scope or 'global',
        stateName = metadata.stateName,
        resourceName = metadata.resourceName,
        value = container.value,
        isActive = container.active ~= false,
        updatedAt = row.updated_at,
        metadata = metadata.context or {}
    }
end

local function queryState(settingKey)
    return MySQL.single.await([[
        SELECT resource_name, setting_key, setting_value, updated_at
        FROM resource_settings
        WHERE resource_name = 'nexa_worldstates'
            AND setting_key = ?
        LIMIT 1
    ]], {
        settingKey
    })
end

function getWorldState(source, payload)
    local actor, actorCode = getActor(source)

    if actorCode ~= 'OK' then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local allowed, code, message = ensureWorldAccess(source, worldPermissions.read)

    if not allowed then
        return respond(false, code, message, nil, nil, nil)
    end

    local normalized = normalizeStatePayload(payload, false)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige World-State-Anfrage.', nil, nil, nil)
    end

    local state = mapState(queryState(normalized.settingKey))

    if state == nil or not state.isActive then
        return respond(false, 'NOT_FOUND', 'World State wurde nicht gefunden.', nil, nil, nil)
    end

    return respond(true, 'OK', 'World State wurde geladen.', {
        state = state
    }, nil, nil)
end

function listWorldStates(source, payload)
    local actor, actorCode = getActor(source)

    if actorCode ~= 'OK' then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local allowed, code, message = ensureWorldAccess(source, worldPermissions.read)

    if not allowed then
        return respond(false, code, message, nil, nil, nil)
    end

    local scope = payload and payload.scope ~= nil and normalizeScope(payload.scope) or nil
    local resourceName = payload and payload.resourceName ~= nil
        and normalizeName(payload.resourceName, worldLimits.maxResourceNameLength) or nil
    local limit = tonumber(payload and payload.limit) or worldLimits.maxStates

    if limit < 1 then
        limit = worldLimits.maxStates
    end

    limit = math.min(math.floor(limit), worldLimits.maxStates)

    local where = { "resource_name = 'nexa_worldstates'", "setting_key LIKE 'ws.%'" }
    local values = {}

    if scope ~= nil then
        where[#where + 1] = 'setting_key LIKE ?'
        values[#values + 1] = scope == 'resource' and 'ws.r.%' or 'ws.g.%'
    end

    if resourceName ~= nil then
        where[#where + 1] = 'setting_key LIKE ?'
        values[#values + 1] = ('ws.r.%s.%%'):format(resourceName)
    end

    values[#values + 1] = limit

    local rows = MySQL.query.await(([[ 
        SELECT resource_name, setting_key, setting_value, updated_at
        FROM resource_settings
        WHERE %s
        ORDER BY updated_at DESC
        LIMIT ?
    ]]):format(table.concat(where, ' AND ')), values) or {}
    local states = {}

    for _, row in ipairs(rows) do
        local mapped = mapState(row)

        if mapped ~= nil and mapped.isActive then
            states[#states + 1] = mapped
        end
    end

    return respond(true, 'OK', 'World States wurden geladen.', {
        states = states
    }, {
        limit = limit
    }, nil)
end

function setWorldState(source, payload)
    local actor, actorCode = getActor(source)

    if actorCode ~= 'OK' then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local allowed, code, message = ensureWorldAccess(source, worldPermissions.manage)

    if not allowed then
        return respond(false, code, message, nil, nil, nil)
    end

    local normalized = normalizeStatePayload(payload, true)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige World-State-Daten.', nil, nil, nil)
    end

    local container = {
        active = true,
        value = normalized.value,
        metadata = {
            source = 'phase10a.world_core',
            scope = normalized.scope,
            stateName = normalized.stateName,
            resourceName = normalized.resourceName,
            ttlSeconds = normalized.ttlSeconds,
            context = normalized.metadata,
            updatedByCharacterId = actor and actor.id or nil
        }
    }

    MySQL.insert.await([[
        INSERT INTO resource_settings (resource_name, setting_key, setting_value)
        VALUES ('nexa_worldstates', ?, ?)
        ON DUPLICATE KEY UPDATE
            setting_value = VALUES(setting_value),
            updated_at = NOW()
    ]], {
        normalized.settingKey,
        encodeJson(container)
    })

    local state = mapState(queryState(normalized.settingKey))
    local auditId = writeWorldAudit('world.state.set', actor, nil, {
        key = normalized.settingKey,
        scope = normalized.scope,
        stateName = normalized.stateName,
        resourceName = normalized.resourceName
    })

    return respond(true, 'OK', 'World State wurde gesetzt.', {
        state = state
    }, nil, auditId)
end

function clearWorldState(source, payload)
    local actor, actorCode = getActor(source)

    if actorCode ~= 'OK' then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local allowed, code, message = ensureWorldAccess(source, worldPermissions.manage)

    if not allowed then
        return respond(false, code, message, nil, nil, nil)
    end

    local normalized = normalizeStatePayload(payload, false)

    if normalized == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige World-State-Daten.', nil, nil, nil)
    end

    local current = queryState(normalized.settingKey)

    if current == nil then
        return respond(false, 'NOT_FOUND', 'World State wurde nicht gefunden.', nil, nil, nil)
    end

    local container = decodeJson(current.setting_value) or {}
    container.active = false
    container.clearedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    container.clearedByCharacterId = actor and actor.id or nil

    local affected = MySQL.update.await([[
        UPDATE resource_settings
        SET setting_value = ?,
            updated_at = NOW()
        WHERE resource_name = 'nexa_worldstates'
            AND setting_key = ?
    ]], {
        encodeJson(container),
        normalized.settingKey
    })

    if affected == nil or affected < 1 then
        return respond(false, 'NOT_FOUND', 'World State wurde nicht gefunden.', nil, nil, nil)
    end

    local auditId = writeWorldAudit('world.state.clear', actor, nil, {
        key = normalized.settingKey,
        scope = normalized.scope,
        stateName = normalized.stateName,
        resourceName = normalized.resourceName
    })

    return respond(true, 'OK', 'World State wurde geloescht.', {
        key = normalized.settingKey
    }, nil, auditId)
end

function getWorldResourceStates(source, payload)
    local actor, actorCode = getActor(source)

    if actorCode ~= 'OK' then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local allowed, code, message = ensureWorldAccess(source, worldPermissions.read)

    if not allowed then
        return respond(false, code, message, nil, nil, nil)
    end

    local resources = type(payload) == 'table' and type(payload.resources) == 'table' and payload.resources or {}
    local states = {}
    local count = 0

    for _, resourceName in ipairs(resources) do
        local normalized = normalizeName(resourceName, worldLimits.maxResourceNameLength)

        if normalized ~= nil then
            count = count + 1

            if count > worldLimits.maxResources then
                break
            end

            states[#states + 1] = {
                resourceName = normalized,
                state = GetResourceState(normalized)
            }
        end
    end

    return respond(true, 'OK', 'Resource-Zustaende wurden geladen.', {
        resources = states
    }, {
        limit = worldLimits.maxResources
    }, nil)
end

exports('world.getState', getWorldState)
exports('world.listStates', listWorldStates)
exports('world.setState', setWorldState)
exports('world.clearState', clearWorldState)
exports('world.getResourceStates', getWorldResourceStates)
