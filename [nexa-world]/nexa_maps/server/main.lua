local mapIndex = {}
local dynamicEntries = {}

local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaMapsConfig.featureFlag)
end

local function buildResponse(success, code, message, data, meta, auditId)
    return exports.nexa_api:buildResponse(success, code, message, data, meta, auditId)
end

local function writeAudit(action, source, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'world',
        severity = 'info',
        action = action,
        resourceName = NEXA_MAPS.resourceName,
        metadata = metadata or {
            source = source
        }
    })

    return result and result.audit_id or nil
end

local function sanitizeEntry(entry)
    return {
        id = entry.id,
        label = entry.label,
        category = entry.category,
        resourceName = entry.resourceName,
        assetType = entry.assetType,
        loadState = entry.loadState,
        active = entry.active == true,
        environment = {
            weatherProfile = entry.environment.weatherProfile,
            timecycleProfile = entry.environment.timecycleProfile
        },
        files = entry.files,
        notes = entry.notes
    }
end

local function rebuildMapIndex()
    mapIndex = {}

    for _, entry in ipairs(NexaMapsServer.entries) do
        local valid = validateMapEntry(entry)

        if valid then
            mapIndex[entry.id] = entry
        else
            exports.nexa_logs:warn(NEXA_MAPS.resourceName, 'Ungueltiger Map-Registry-Eintrag.', {
                id = entry.id
            })
        end
    end

    for _, entry in pairs(dynamicEntries) do
        mapIndex[entry.id] = entry
    end
end

local function matchesQuery(entry, payload)
    payload = payload or {}

    if payload.category ~= nil and entry.category ~= payload.category then
        return false
    end

    if payload.activeOnly == true and entry.active ~= true then
        return false
    end

    return true
end

local function collectEntries(payload)
    local entries = {}

    for _, entry in ipairs(NexaMapsServer.entries) do
        if matchesQuery(entry, payload) then
            entries[#entries + 1] = sanitizeEntry(entry)
        end

        if #entries >= NexaMapsServer.maxClientEntries then
            return entries
        end
    end

    for _, entry in pairs(dynamicEntries) do
        if matchesQuery(entry, payload) then
            entries[#entries + 1] = sanitizeEntry(entry)
        end

        if #entries >= NexaMapsServer.maxClientEntries then
            return entries
        end
    end

    return entries
end

local function getStatus()
    local count = 0

    for _ in pairs(mapIndex) do
        count = count + 1
    end

    return {
        resourceName = NEXA_MAPS.resourceName,
        version = NEXA_MAPS.version,
        enabled = isEnabled(),
        registryCount = count,
        environment = NexaMapsServer.environment
    }
end

local function listMaps(source, payload)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Map-Registry ist deaktiviert.', nil, nil, nil)
    end

    local valid, code = validateMapQuery(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Map-Anfrage.', nil, nil, nil)
    end

    local entries = collectEntries(payload)

    exports.nexa_logs:info(NEXA_MAPS.resourceName, 'Map-Registry wurde gelesen.', {
        source = source,
        count = #entries
    })

    return buildResponse(true, 'OK', 'Map-Registry wurde geladen.', {
        maps = entries,
        categories = NexaMapsServer.categories,
        environment = NexaMapsServer.environment
    }, nil, nil)
end

local function getMap(source, mapId)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Map-Registry ist deaktiviert.', nil, nil, nil)
    end

    local entry = type(mapId) == 'string' and mapIndex[mapId] or nil

    if entry == nil then
        return buildResponse(false, 'NOT_FOUND', 'Map-Eintrag wurde nicht gefunden.', nil, nil, nil)
    end

    exports.nexa_logs:info(NEXA_MAPS.resourceName, 'Map-Registry-Eintrag wurde gelesen.', {
        source = source,
        mapId = mapId
    })

    return buildResponse(true, 'OK', 'Map-Eintrag wurde geladen.', {
        map = sanitizeEntry(entry)
    }, nil, nil)
end

local function registerMap(entry)
    local valid, code = validateMapEntry(entry)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Map-Registry-Daten.', nil, nil, nil)
    end

    dynamicEntries[entry.id] = entry
    rebuildMapIndex()

    local auditId = writeAudit('maps.registry.register', 0, {
        mapId = entry.id,
        resourceName = entry.resourceName,
        assetType = entry.assetType
    })

    return buildResponse(true, 'OK', 'Map-Registry-Eintrag wurde registriert.', {
        mapId = entry.id
    }, nil, auditId)
end

local function updateLoadState(mapId, loadState, active)
    local entry = type(mapId) == 'string' and mapIndex[mapId] or nil

    if entry == nil then
        return buildResponse(false, 'NOT_FOUND', 'Map-Eintrag wurde nicht gefunden.', nil, nil, nil)
    end

    local candidate = {
        id = entry.id,
        label = entry.label,
        category = entry.category,
        resourceName = entry.resourceName,
        assetType = entry.assetType,
        loadState = loadState,
        active = active == true,
        environment = entry.environment,
        files = entry.files
    }

    local valid, code = validateMapEntry(candidate)

    if not valid then
        return buildResponse(false, code, 'Ungueltiger Ladezustand.', nil, nil, nil)
    end

    entry.loadState = loadState
    entry.active = active == true

    local auditId = writeAudit('maps.registry.state', 0, {
        mapId = mapId,
        loadState = loadState,
        active = entry.active
    })

    return buildResponse(true, 'OK', 'Map-Ladezustand wurde aktualisiert.', {
        mapId = mapId,
        loadState = loadState,
        active = entry.active
    }, nil, auditId)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    rebuildMapIndex()

    exports.nexa_logs:info(NEXA_MAPS.resourceName, 'Map-Registry gestartet.', {
        version = NEXA_MAPS.version,
        featureFlag = NexaMapsConfig.featureFlag
    })
end)

rebuildMapIndex()

exports('getStatus', getStatus)
exports('maps.list', listMaps)
exports('maps.get', getMap)
exports('maps.register', registerMap)
exports('maps.updateLoadState', updateLoadState)
