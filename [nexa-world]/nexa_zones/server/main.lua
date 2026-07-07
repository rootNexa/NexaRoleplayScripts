local zoneIndex = {}
local sourceZoneState = {}

local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaZonesConfig.featureFlag)
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
        resourceName = NEXA_ZONES.resourceName,
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

local function canAccessZone(source, zone)
    return hasPermission(source, zone.permission)
end

local function sanitizeZone(zone)
    local sanitized = {
        id = zone.id,
        label = zone.label,
        type = zone.type,
        category = zone.category or 'public',
        safezone = zone.safezone == true
    }

    if zone.type == 'sphere' then
        sanitized.coords = zone.coords
        sanitized.radius = tonumber(zone.radius)
    elseif zone.type == 'box' then
        sanitized.coords = zone.coords
        sanitized.size = zone.size
        sanitized.rotation = tonumber(zone.rotation) or 0.0
    elseif zone.type == 'poly' then
        sanitized.points = zone.points
        sanitized.thickness = tonumber(zone.thickness)
    end

    return sanitized
end

local function refreshZoneIndex()
    zoneIndex = {}

    for _, zone in ipairs(NexaZonesServer.zones) do
        local valid = validateZoneDefinition(zone)

        if valid then
            zoneIndex[zone.id] = zone
        else
            exports.nexa_logs:warn(NEXA_ZONES.resourceName, 'Ungueltige Zone in Server-Konfiguration.', {
                id = zone.id
            })
        end
    end
end

local function listAllowedZones(source)
    local zones = {}

    for _, zone in ipairs(NexaZonesServer.zones) do
        if canAccessZone(source, zone) then
            zones[#zones + 1] = sanitizeZone(zone)
        end

        if #zones >= NexaZonesServer.maxClientZones then
            break
        end
    end

    return zones
end

local function getStatus()
    local zoneCount = 0

    for _ in pairs(zoneIndex) do
        zoneCount = zoneCount + 1
    end

    return {
        resourceName = NEXA_ZONES.resourceName,
        version = NEXA_ZONES.version,
        enabled = isEnabled(),
        zoneCount = zoneCount
    }
end

local function getAvailable(source)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Zonen sind deaktiviert.', nil, nil, nil)
    end

    local zones = listAllowedZones(source)

    exports.nexa_logs:info(NEXA_ZONES.resourceName, 'Zonen wurden serverseitig gefiltert.', {
        source = source,
        count = #zones
    })

    return buildResponse(true, 'OK', 'Zonen wurden geladen.', {
        zones = zones
    }, nil, nil)
end

local function getZone(zoneId)
    if type(zoneId) ~= 'string' or zoneIndex[zoneId] == nil then
        return buildResponse(false, 'NOT_FOUND', 'Zone wurde nicht gefunden.', nil, nil, nil)
    end

    return buildResponse(true, 'OK', 'Zone wurde geladen.', {
        zone = sanitizeZone(zoneIndex[zoneId])
    }, nil, nil)
end

local function getSourceCoords(source)
    local ped = GetPlayerPed(source)

    if ped == 0 then
        return nil
    end

    return GetEntityCoords(ped)
end

local function inSphere(coords, zone)
    local dx = coords.x - zone.coords.x
    local dy = coords.y - zone.coords.y
    local dz = coords.z - zone.coords.z
    local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))

    return distance <= (tonumber(zone.radius) + NexaZonesServer.validationDistance)
end

local function inBox(coords, zone)
    local halfX = tonumber(zone.size.x) / 2 + NexaZonesServer.validationDistance
    local halfY = tonumber(zone.size.y) / 2 + NexaZonesServer.validationDistance
    local halfZ = tonumber(zone.size.z) / 2 + NexaZonesServer.validationDistance

    return math.abs(coords.x - zone.coords.x) <= halfX
        and math.abs(coords.y - zone.coords.y) <= halfY
        and math.abs(coords.z - zone.coords.z) <= halfZ
end

local function inPoly2d(coords, points)
    local inside = false
    local j = #points

    for i = 1, #points do
        local pi = points[i]
        local pj = points[j]

        if ((pi.y > coords.y) ~= (pj.y > coords.y))
            and (coords.x < (pj.x - pi.x) * (coords.y - pi.y) / (pj.y - pi.y) + pi.x) then
            inside = not inside
        end

        j = i
    end

    return inside
end

local function inPoly(coords, zone)
    local baseZ = tonumber(zone.points[1].z)
    local thickness = tonumber(zone.thickness) + NexaZonesServer.validationDistance

    return math.abs(coords.z - baseZ) <= thickness
        and inPoly2d(coords, zone.points)
end

local function isSourceInsideZone(source, zone)
    local coords = getSourceCoords(source)

    if coords == nil then
        return false
    end

    if zone.type == 'sphere' then
        return inSphere(coords, zone)
    elseif zone.type == 'box' then
        return inBox(coords, zone)
    elseif zone.type == 'poly' then
        return inPoly(coords, zone)
    end

    return false
end

local function actionAllowed(zone, action)
    if type(zone.criticalActions) ~= 'table' then
        return false
    end

    for _, allowedAction in ipairs(zone.criticalActions) do
        if allowedAction == action then
            return true
        end
    end

    return false
end

local function validateCriticalAction(source, payload)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Zonen sind deaktiviert.', nil, nil, nil)
    end

    local valid, code = validateCriticalZonePayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Zonenanfrage.', nil, nil, nil)
    end

    local zone = zoneIndex[payload.zoneId]

    if zone == nil then
        return buildResponse(false, 'NOT_FOUND', 'Zone wurde nicht gefunden.', nil, nil, nil)
    end

    if not canAccessZone(source, zone) then
        return buildResponse(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    if not actionAllowed(zone, payload.action) then
        return buildResponse(false, 'NO_PERMISSION', 'Diese Zonenaktion ist nicht freigegeben.', nil, nil, nil)
    end

    if not isSourceInsideZone(source, zone) then
        local auditId = writeAudit('zones.critical.denied', source, {
            zoneId = payload.zoneId,
            action = payload.action,
            reason = 'outside_zone'
        })

        return buildResponse(false, 'INVALID_INPUT', 'Du bist nicht in der passenden Zone.', nil, nil, auditId)
    end

    local auditId = writeAudit('zones.critical.validated', source, {
        zoneId = payload.zoneId,
        action = payload.action
    })

    exports.nexa_logs:info(NEXA_ZONES.resourceName, 'Kritische Zonenaktion serverseitig validiert.', {
        source = source,
        zoneId = payload.zoneId,
        action = payload.action
    })

    return buildResponse(true, 'OK', 'Zonenaktion wurde validiert.', {
        zoneId = payload.zoneId,
        action = payload.action,
        allowed = true
    }, nil, auditId)
end

local function reportTransition(source, payload)
    local valid, code = validateZoneReport(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Zonenmeldung.', nil, nil, nil)
    end

    local zone = zoneIndex[payload.zoneId]

    if zone == nil or not canAccessZone(source, zone) then
        return buildResponse(false, 'NO_PERMISSION', 'Zone ist nicht verfuegbar.', nil, nil, nil)
    end

    sourceZoneState[source] = sourceZoneState[source] or {}
    sourceZoneState[source][payload.zoneId] = payload.transition == 'entered'

    exports.nexa_logs:info(NEXA_ZONES.resourceName, 'Zonenwechsel gemeldet.', {
        source = source,
        zoneId = payload.zoneId,
        transition = payload.transition
    })

    if zone.safezone == true or zone.permission ~= nil then
        writeAudit('zones.transition.' .. payload.transition, source, {
            zoneId = payload.zoneId,
            safezone = zone.safezone == true,
            permissionZone = zone.permission ~= nil
        })
    end

    return buildResponse(true, 'OK', 'Zonenmeldung wurde angenommen.', nil, nil, nil)
end

AddEventHandler('playerDropped', function()
    sourceZoneState[source] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    refreshZoneIndex()

    exports.nexa_logs:info(NEXA_ZONES.resourceName, 'Zonen gestartet.', {
        version = NEXA_ZONES.version,
        featureFlag = NexaZonesConfig.featureFlag
    })
end)

refreshZoneIndex()

exports('getStatus', getStatus)
exports('zones.getAvailable', getAvailable)
exports('zones.getZone', getZone)
exports('zones.validateCriticalAction', validateCriticalAction)
exports('zones.reportTransition', reportTransition)
