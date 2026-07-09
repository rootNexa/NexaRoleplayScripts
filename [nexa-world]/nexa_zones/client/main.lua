local activeZones = {}
local insideZones = {}

local function sendTransition(zoneId, eventName)
    TriggerServerEvent(eventName, {
        zoneId = zoneId
    })
end

local function clearZones()
    activeZones = {}
    insideZones = {}
end

local function toVec3(coords)
    if type(coords) ~= 'table' then
        return nil
    end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)

    if not x or not y or not z then
        return nil
    end

    return vector3(x, y, z)
end

local function rotatePoint(x, y, degrees)
    local radians = math.rad(-(tonumber(degrees) or 0.0))
    local cosValue = math.cos(radians)
    local sinValue = math.sin(radians)

    return (x * cosValue) - (y * sinValue), (x * sinValue) + (y * cosValue)
end

local function isInsideSphere(coords, zone)
    return #(coords - zone.coords) <= zone.radius
end

local function isInsideBox(coords, zone)
    local dx = coords.x - zone.coords.x
    local dy = coords.y - zone.coords.y
    local localX, localY = rotatePoint(dx, dy, zone.rotation)

    return math.abs(localX) <= zone.size.x / 2
        and math.abs(localY) <= zone.size.y / 2
        and math.abs(coords.z - zone.coords.z) <= zone.size.z / 2
end

local function isInsidePoly2d(coords, points)
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

local function isInsidePoly(coords, zone)
    if #zone.points < 3 then
        return false
    end

    local baseZ = zone.points[1].z

    return math.abs(coords.z - baseZ) <= zone.thickness
        and isInsidePoly2d(coords, zone.points)
end

local function isInsideZone(coords, zone)
    if zone.type == 'sphere' then
        return isInsideSphere(coords, zone)
    end

    if zone.type == 'box' then
        return isInsideBox(coords, zone)
    end

    if zone.type == 'poly' then
        return isInsidePoly(coords, zone)
    end

    return false
end

local function normalizeZone(entry)
    if type(entry) ~= 'table' or type(entry.id) ~= 'string' then
        return nil
    end

    local zone = {
        id = entry.id,
        type = entry.type,
        label = entry.label,
        safezone = entry.safezone == true,
        category = entry.category
    }

    if entry.type == 'sphere' then
        zone.coords = toVec3(entry.coords)
        zone.radius = tonumber(entry.radius)

        if not zone.coords or not zone.radius then
            return nil
        end
    elseif entry.type == 'box' then
        zone.coords = toVec3(entry.coords)
        zone.size = toVec3(entry.size)
        zone.rotation = tonumber(entry.rotation) or 0.0

        if not zone.coords or not zone.size then
            return nil
        end
    elseif entry.type == 'poly' then
        zone.points = {}
        zone.thickness = tonumber(entry.thickness)

        for _, point in ipairs(entry.points or {}) do
            local normalizedPoint = toVec3(point)

            if normalizedPoint then
                zone.points[#zone.points + 1] = normalizedPoint
            end
        end

        if not zone.thickness or #zone.points < 3 then
            return nil
        end
    else
        return nil
    end

    return zone
end

local function applyZones(zones)
    clearZones()

    for _, entry in ipairs(zones or {}) do
        local zone = normalizeZone(entry)

        if zone then
            activeZones[zone.id] = zone
        end
    end
end

local function refreshZones()
    local zonesRequest = promise.new()
    local request = exports.nexa_api:TriggerServerCallback('nexa:zones:cb:getAvailable', {}, function(response)
        zonesRequest:resolve(response)
    end, NexaZonesClient.callbackTimeoutMs)

    if type(request) == 'table' and request.ok == false then
        return
    end

    local response = Citizen.Await(zonesRequest)

    if type(response) == 'table' and response.ok == true and response.data ~= nil then
        applyZones(response.data.zones or {})
    end
end

local function tickZones()
    local ped = PlayerPedId()

    if ped == 0 then
        return
    end

    local coords = GetEntityCoords(ped)

    for zoneId, zone in pairs(activeZones) do
        local wasInside = insideZones[zoneId] == true
        local isInside = isInsideZone(coords, zone)

        if isInside and not wasInside then
            insideZones[zoneId] = true
            sendTransition(zoneId, NEXA_ZONES_EVENTS.entered)
        elseif not isInside and wasInside then
            insideZones[zoneId] = nil
            sendTransition(zoneId, NEXA_ZONES_EVENTS.left)
        end
    end
end

RegisterNetEvent(NEXA_ZONES_EVENTS.refresh, refreshZones)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    clearZones()
end)

CreateThread(function()
    Wait(1500)
    refreshZones()

    while true do
        tickZones()
        Wait(NexaZonesClient.tickMs)
    end
end)
