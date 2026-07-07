local dynamicBlips = {}

local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaBlipsConfig.featureFlag)
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
        resourceName = NEXA_BLIPS.resourceName,
        metadata = metadata or {
            source = source
        }
    })

    return result and result.audit_id or nil
end

local function hasPermission(source, permission)
    if permission == nil then
        return true
    end

    local result = exports.nexa_api['permission.has'](source, permission)

    return result == true or (type(result) == 'table' and result.success == true)
end

local function hasJob(source, jobName)
    if jobName == nil then
        return true
    end

    local result = exports.nexa_api['job.getCharacter'](source, {})

    return type(result) == 'table'
        and result.success == true
        and result.data ~= nil
        and result.data.job ~= nil
        and result.data.job.job_name == jobName
end

local function hasFaction(source, factionName)
    if factionName == nil then
        return true
    end

    local result = exports.nexa_api['faction.getCurrent'](source, {
        factionName = factionName
    })

    return type(result) == 'table'
        and result.success == true
        and result.data ~= nil
        and result.data.membership ~= nil
        and result.data.membership.faction ~= nil
        and result.data.membership.faction.name == factionName
end

local function sanitizeBlip(blip)
    return {
        id = blip.id,
        label = blip.label,
        category = blip.category or 'public',
        coords = {
            x = tonumber(blip.coords.x),
            y = tonumber(blip.coords.y),
            z = tonumber(blip.coords.z)
        },
        sprite = tonumber(blip.sprite) or 1,
        color = tonumber(blip.color) or 0,
        scale = tonumber(blip.scale) or 0.75,
        display = tonumber(blip.display) or 4,
        shortRange = blip.shortRange ~= false
    }
end

local function canSeeBlip(source, blip)
    return hasPermission(source, blip.permission)
        and hasJob(source, blip.job)
        and hasFaction(source, blip.faction)
end

local function collectAllowedBlips(source)
    local blips = {}

    for _, blip in ipairs(NexaBlipsServer.publicBlips) do
        blips[#blips + 1] = sanitizeBlip(blip)
    end

    for _, blip in ipairs(NexaBlipsServer.restrictedBlips) do
        if canSeeBlip(source, blip) then
            blips[#blips + 1] = sanitizeBlip(blip)
        end
    end

    for _, blip in pairs(dynamicBlips) do
        if canSeeBlip(source, blip) then
            blips[#blips + 1] = sanitizeBlip(blip)
        end
    end

    return blips
end

local function getStatus()
    local dynamicCount = 0

    for _ in pairs(dynamicBlips) do
        dynamicCount = dynamicCount + 1
    end

    return {
        resourceName = NEXA_BLIPS.resourceName,
        version = NEXA_BLIPS.version,
        enabled = isEnabled(),
        dynamicCount = dynamicCount
    }
end

local function getAvailable(source)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Blips sind deaktiviert.', nil, nil, nil)
    end

    local blips = collectAllowedBlips(source)
    local auditId = writeAudit('blips.list', source, {
        count = #blips
    })

    exports.nexa_logs:info(NEXA_BLIPS.resourceName, 'Blips wurden serverseitig gefiltert.', {
        source = source,
        count = #blips
    })

    return buildResponse(true, 'OK', 'Blips wurden geladen.', {
        blips = blips
    }, nil, auditId)
end

local function registerDynamic(blip)
    local valid, code = validateBlipPayload(blip)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Blipdaten.', nil, nil, nil)
    end

    local dynamicCount = 0

    for _ in pairs(dynamicBlips) do
        dynamicCount = dynamicCount + 1
    end

    if dynamicCount >= NexaBlipsServer.maxDynamicBlips and dynamicBlips[blip.id] == nil then
        return buildResponse(false, 'CONFLICT', 'Zu viele dynamische Blips.', nil, nil, nil)
    end

    dynamicBlips[blip.id] = blip
    writeAudit('blips.dynamic.register', 0, {
        id = blip.id,
        category = blip.category
    })

    return buildResponse(true, 'OK', 'Dynamischer Blip wurde registriert.', {
        id = blip.id
    }, nil, nil)
end

local function removeDynamic(blipId)
    if type(blipId) ~= 'string' or dynamicBlips[blipId] == nil then
        return buildResponse(false, 'NOT_FOUND', 'Dynamischer Blip wurde nicht gefunden.', nil, nil, nil)
    end

    dynamicBlips[blipId] = nil
    writeAudit('blips.dynamic.remove', 0, {
        id = blipId
    })

    return buildResponse(true, 'OK', 'Dynamischer Blip wurde entfernt.', {
        id = blipId
    }, nil, nil)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_BLIPS.resourceName, 'Blips gestartet.', {
        version = NEXA_BLIPS.version,
        featureFlag = NexaBlipsConfig.featureFlag
    })
end)

exports('getStatus', getStatus)
exports('blips.getAvailable', getAvailable)
exports('blips.registerDynamic', registerDynamic)
exports('blips.removeDynamic', removeDynamic)
