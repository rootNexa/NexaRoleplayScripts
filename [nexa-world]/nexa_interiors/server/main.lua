local interiorIndex = {}
local dynamicInteriors = {}

local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaInteriorsConfig.featureFlag)
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

local function writeAudit(action, source, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'world',
        severity = 'info',
        action = action,
        resourceName = NEXA_INTERIORS.resourceName,
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

    local result = exports.nexa_api:HasPermission(source, permission)

    return type(result) == 'table'
        and result.ok == true
        and result.data ~= nil
        and result.data.allowed == true
end

local function canAccessInterior(source, interior)
    return hasPermission(source, interior.permission)
end

local function sanitizePoint(point)
    return {
        id = point.id,
        label = point.label,
        coords = {
            x = tonumber(point.coords.x),
            y = tonumber(point.coords.y),
            z = tonumber(point.coords.z)
        },
        heading = tonumber(point.heading) or 0.0
    }
end

local function sanitizePoints(points)
    local sanitized = {}

    for _, point in ipairs(points or {}) do
        sanitized[#sanitized + 1] = sanitizePoint(point)
    end

    return sanitized
end

local function sanitizeInterior(interior)
    return {
        id = interior.id,
        label = interior.label,
        type = interior.type or 'interior',
        mlo = {
            registryName = interior.mlo.registryName,
            assetStatus = interior.mlo.assetStatus or 'planned',
            version = interior.mlo.version or '1.0.0'
        },
        entryPoints = sanitizePoints(interior.entryPoints),
        exitPoints = sanitizePoints(interior.exitPoints),
        doorlock = {
            prepared = interior.doorlock ~= nil and interior.doorlock.prepared == true,
            group = interior.doorlock ~= nil and interior.doorlock.group or nil,
            doors = interior.doorlock ~= nil and interior.doorlock.doors or {}
        },
        links = {
            storage = interior.links ~= nil and interior.links.storage or nil,
            garage = interior.links ~= nil and interior.links.garage or nil,
            faction = interior.links ~= nil and interior.links.faction or nil
        }
    }
end

local function rebuildInteriorIndex()
    interiorIndex = {}

    for _, interior in ipairs(NexaInteriorsServer.interiors) do
        local valid = validateInteriorDefinition(interior)

        if valid then
            interiorIndex[interior.id] = interior
        else
            exports.nexa_logs:warn(NEXA_INTERIORS.resourceName, 'Ungueltiger Interior-Registry-Eintrag.', {
                id = interior.id
            })
        end
    end

    for _, interior in pairs(dynamicInteriors) do
        interiorIndex[interior.id] = interior
    end
end

local function listAllowedInteriors(source)
    local interiors = {}

    for _, interior in ipairs(NexaInteriorsServer.interiors) do
        if canAccessInterior(source, interior) then
            interiors[#interiors + 1] = sanitizeInterior(interior)
        end

        if #interiors >= NexaInteriorsServer.maxClientInteriors then
            return interiors
        end
    end

    for _, interior in pairs(dynamicInteriors) do
        if canAccessInterior(source, interior) then
            interiors[#interiors + 1] = sanitizeInterior(interior)
        end

        if #interiors >= NexaInteriorsServer.maxClientInteriors then
            return interiors
        end
    end

    return interiors
end

local function getStatus()
    local count = 0

    for _ in pairs(interiorIndex) do
        count = count + 1
    end

    return {
        resourceName = NEXA_INTERIORS.resourceName,
        version = NEXA_INTERIORS.version,
        enabled = isEnabled(),
        interiorCount = count
    }
end

local function getAvailable(source)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Interiors sind deaktiviert.', nil, nil, nil)
    end

    local interiors = listAllowedInteriors(source)

    exports.nexa_logs:info(NEXA_INTERIORS.resourceName, 'Interiors wurden serverseitig gefiltert.', {
        source = source,
        count = #interiors
    })

    return buildResponse(true, 'OK', 'Interiors wurden geladen.', {
        interiors = interiors
    }, nil, nil)
end

local function getInterior(source, interiorId)
    local interior = type(interiorId) == 'string' and interiorIndex[interiorId] or nil

    if interior == nil then
        return buildResponse(false, 'NOT_FOUND', 'Interior wurde nicht gefunden.', nil, nil, nil)
    end

    if not canAccessInterior(source, interior) then
        return buildResponse(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    return buildResponse(true, 'OK', 'Interior wurde geladen.', {
        interior = sanitizeInterior(interior)
    }, nil, nil)
end

local function getSourceCoords(source)
    local ped = GetPlayerPed(source)

    if ped == 0 then
        return nil
    end

    return GetEntityCoords(ped)
end

local function findPoint(interior, direction, pointId)
    local points = direction == 'entry' and interior.entryPoints or interior.exitPoints

    for _, point in ipairs(points or {}) do
        if point.id == pointId then
            return point
        end
    end

    return nil
end

local function isNearPoint(source, point)
    local coords = getSourceCoords(source)

    if coords == nil then
        return false
    end

    local dx = coords.x - point.coords.x
    local dy = coords.y - point.coords.y
    local dz = coords.z - point.coords.z
    local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))

    return distance <= NexaInteriorsServer.accessDistance
end

local function validateAccess(source, payload)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Interiors sind deaktiviert.', nil, nil, nil)
    end

    local valid, code = validateInteriorAccessPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Interior-Anfrage.', nil, nil, nil)
    end

    local interior = interiorIndex[payload.interiorId]

    if interior == nil then
        return buildResponse(false, 'NOT_FOUND', 'Interior wurde nicht gefunden.', nil, nil, nil)
    end

    if not canAccessInterior(source, interior) then
        return buildResponse(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    local point = findPoint(interior, payload.direction, payload.pointId)

    if point == nil then
        return buildResponse(false, 'NOT_FOUND', 'Interior-Punkt wurde nicht gefunden.', nil, nil, nil)
    end

    if not isNearPoint(source, point) then
        local auditId = writeAudit('interiors.access.denied', source, {
            interiorId = payload.interiorId,
            pointId = payload.pointId,
            direction = payload.direction,
            reason = 'distance'
        })

        return buildResponse(false, 'INVALID_INPUT', 'Du bist nicht am passenden Interior-Punkt.', nil, nil, auditId)
    end

    local auditId = writeAudit('interiors.access.validated', source, {
        interiorId = payload.interiorId,
        pointId = payload.pointId,
        direction = payload.direction
    })

    exports.nexa_logs:info(NEXA_INTERIORS.resourceName, 'Interior-Zugriff serverseitig validiert.', {
        source = source,
        interiorId = payload.interiorId,
        pointId = payload.pointId,
        direction = payload.direction
    })

    return buildResponse(true, 'OK', 'Interior-Zugriff wurde validiert.', {
        interiorId = payload.interiorId,
        pointId = payload.pointId,
        direction = payload.direction,
        allowed = true
    }, nil, auditId)
end

local function registerInterior(interior)
    local valid, code = validateInteriorDefinition(interior)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Interior-Daten.', nil, nil, nil)
    end

    dynamicInteriors[interior.id] = interior
    rebuildInteriorIndex()

    local auditId = writeAudit('interiors.registry.register', 0, {
        interiorId = interior.id,
        registryName = interior.mlo.registryName
    })

    return buildResponse(true, 'OK', 'Interior wurde registriert.', {
        interiorId = interior.id
    }, nil, auditId)
end

local function removeInterior(interiorId)
    if type(interiorId) ~= 'string' or dynamicInteriors[interiorId] == nil then
        return buildResponse(false, 'NOT_FOUND', 'Interior wurde nicht gefunden.', nil, nil, nil)
    end

    dynamicInteriors[interiorId] = nil
    rebuildInteriorIndex()

    local auditId = writeAudit('interiors.registry.remove', 0, {
        interiorId = interiorId
    })

    return buildResponse(true, 'OK', 'Interior wurde entfernt.', {
        interiorId = interiorId
    }, nil, auditId)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    rebuildInteriorIndex()

    exports.nexa_logs:info(NEXA_INTERIORS.resourceName, 'Interiors gestartet.', {
        version = NEXA_INTERIORS.version,
        featureFlag = NexaInteriorsConfig.featureFlag
    })
end)

rebuildInteriorIndex()

exports('getStatus', getStatus)
exports('interiors.getAvailable', getAvailable)
exports('interiors.getInterior', getInterior)
exports('interiors.validateAccess', validateAccess)
exports('interiors.registerInterior', registerInterior)
exports('interiors.removeInterior', removeInterior)
