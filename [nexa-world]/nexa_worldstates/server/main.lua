local states = {}

local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaWorldStatesConfig.featureFlag)
end

local function buildResponse(success, code, message, data, meta, auditId)
    return {
        ok = success == true,
        success = success == true,
        data = data,
        error = success == true and nil or {
            code = code,
            message = message,
            details = meta
        },
        code = code,
        message = message,
        meta = meta,
        audit_id = auditId
    }
end

local function unavailable()
    return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'World States sind deaktiviert.', nil, nil, nil)
end

local function copyTable(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}

    for key, item in pairs(value) do
        copy[key] = copyTable(item)
    end

    return copy
end

local function normalizeScope(scope)
    if scope == nil or scope == '' then
        return 'global'
    end

    return tostring(scope):lower()
end

local function normalizePayload(payload)
    payload = payload or {}

    local scope = normalizeScope(payload.scope)
    local stateName = payload.stateName or payload.name
    local resourceName = payload.resourceName

    if scope == 'resource' and not resourceName then
        resourceName = GetCurrentResourceName()
    end

    return scope, resourceName, stateName
end

local function makeKey(scope, resourceName, stateName)
    if scope == 'resource' then
        return ('resource:%s:%s'):format(resourceName, stateName)
    end

    return ('global:%s'):format(stateName)
end

local function isExpired(entry)
    return entry ~= nil and entry.expiresAt ~= nil and os.time() >= entry.expiresAt
end

local function removeExpired()
    for key, entry in pairs(states) do
        if isExpired(entry) then
            states[key] = nil
        end
    end
end

local function writeAudit(action, source, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'world',
        severity = 'info',
        action = action,
        resourceName = NEXA_WORLDSTATES.resourceName,
        metadata = metadata or {
            source = source
        }
    })

    return result and result.audit_id or nil
end

local function toPublicEntry(entry)
    if not entry then
        return nil
    end

    return {
        scope = entry.scope,
        resourceName = entry.resourceName,
        stateName = entry.stateName,
        value = copyTable(entry.value),
        metadata = copyTable(entry.metadata),
        updatedBy = entry.updatedBy,
        updatedAt = entry.updatedAt,
        expiresAt = entry.expiresAt
    }
end

local function getStatus()
    removeExpired()

    local count = 0

    for _ in pairs(states) do
        count = count + 1
    end

    return {
        resourceName = NEXA_WORLDSTATES.resourceName,
        version = NEXA_WORLDSTATES.version,
        enabled = isEnabled(),
        stateCount = count
    }
end

local function getState(source, payload)
    if not isEnabled() then
        return unavailable()
    end

    local valid, code = validateWorldStatePayload(payload, false)

    if not valid then
        return buildResponse(false, code, 'Ungueltige World-State-Anfrage.', nil, nil, nil)
    end

    removeExpired()

    local scope, resourceName, stateName = normalizePayload(payload)
    local entry = states[makeKey(scope, resourceName, stateName)]

    if entry == nil then
        return buildResponse(false, 'NOT_FOUND', 'World State wurde nicht gefunden.', nil, nil, nil)
    end

    return buildResponse(true, 'OK', 'World State wurde geladen.', {
        state = toPublicEntry(entry)
    }, nil, nil)
end

local function listStates(source, payload)
    if not isEnabled() then
        return unavailable()
    end

    local valid, code = validateWorldStateListPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige World-State-Liste.', nil, nil, nil)
    end

    removeExpired()

    payload = payload or {}

    local scope = payload.scope and normalizeScope(payload.scope) or nil
    local resourceName = payload.resourceName
    local limit = math.min(tonumber(payload.limit) or NexaWorldStatesServer.maxListLimit, NexaWorldStatesServer.maxListLimit)
    local list = {}

    for _, entry in pairs(states) do
        if (scope == nil or entry.scope == scope)
            and (resourceName == nil or entry.resourceName == resourceName) then
            list[#list + 1] = toPublicEntry(entry)

            if #list >= limit then
                break
            end
        end
    end

    table.sort(list, function(left, right)
        return left.stateName < right.stateName
    end)

    return buildResponse(true, 'OK', 'World States wurden geladen.', {
        states = list
    }, nil, nil)
end

local function setState(source, payload)
    if not isEnabled() then
        return unavailable()
    end

    local valid, code = validateWorldStatePayload(payload, true)

    if not valid then
        return buildResponse(false, code, 'Ungueltige World-State-Daten.', nil, nil, nil)
    end

    local scope, resourceName, stateName = normalizePayload(payload)
    local key = makeKey(scope, resourceName, stateName)
    local now = os.time()
    local ttl = tonumber(payload.ttlSeconds)
    local auditId = writeAudit('worldstates.set', source, {
        scope = scope,
        resourceName = resourceName,
        stateName = stateName
    })

    states[key] = {
        scope = scope,
        resourceName = resourceName,
        stateName = stateName,
        value = copyTable(payload.value),
        metadata = copyTable(payload.metadata),
        updatedBy = source,
        updatedAt = now,
        expiresAt = ttl and (now + ttl) or nil
    }

    exports.nexa_logs:info(NEXA_WORLDSTATES.resourceName, 'World State gesetzt.', {
        source = source,
        scope = scope,
        resourceName = resourceName,
        stateName = stateName
    })

    return buildResponse(true, 'OK', 'World State wurde gesetzt.', {
        state = toPublicEntry(states[key])
    }, nil, auditId)
end

local function clearState(source, payload)
    if not isEnabled() then
        return unavailable()
    end

    local valid, code = validateWorldStatePayload(payload, false)

    if not valid then
        return buildResponse(false, code, 'Ungueltige World-State-Daten.', nil, nil, nil)
    end

    local scope, resourceName, stateName = normalizePayload(payload)
    local key = makeKey(scope, resourceName, stateName)

    if states[key] == nil then
        return buildResponse(false, 'NOT_FOUND', 'World State wurde nicht gefunden.', nil, nil, nil)
    end

    states[key] = nil

    local auditId = writeAudit('worldstates.clear', source, {
        scope = scope,
        resourceName = resourceName,
        stateName = stateName
    })

    return buildResponse(true, 'OK', 'World State wurde geloescht.', {
        scope = scope,
        resourceName = resourceName,
        stateName = stateName
    }, nil, auditId)
end

local function getResourceStates(source, payload)
    if not isEnabled() then
        return unavailable()
    end

    local valid, code = validateResourceStatePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Resource-State-Anfrage.', nil, nil, nil)
    end

    payload = payload or {}

    local resources = payload.resources or NexaWorldStatesServer.knownResources
    local resourceStates = {}

    for _, resourceName in ipairs(resources) do
        resourceStates[#resourceStates + 1] = {
            resourceName = resourceName,
            state = GetResourceState(resourceName)
        }
    end

    return buildResponse(true, 'OK', 'Resource States wurden geladen.', {
        resources = resourceStates
    }, nil, nil)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_WORLDSTATES.resourceName, 'World States gestartet.', {
        version = NEXA_WORLDSTATES.version,
        featureFlag = NexaWorldStatesConfig.featureFlag
    })
end)

exports('getStatus', getStatus)
exports('worldstates.getState', getState)
exports('worldstates.listStates', listStates)
exports('worldstates.setState', setState)
exports('worldstates.clearState', clearState)
exports('worldstates.getResourceStates', getResourceStates)
