local activeZones = {}

local function clearZones()
    for _, zone in pairs(activeZones) do
        if zone.remove ~= nil then
            zone:remove()
        end
    end

    activeZones = {}
end

local function sendTransition(zoneId, eventName)
    TriggerServerEvent(eventName, {
        zoneId = zoneId
    })
end

local function createZone(entry)
    local options = {
        debug = NexaZonesClient.debug,
        onEnter = function()
            sendTransition(entry.id, NEXA_ZONES_EVENTS.entered)
        end,
        onExit = function()
            sendTransition(entry.id, NEXA_ZONES_EVENTS.left)
        end
    }

    if entry.type == 'sphere' then
        options.coords = vec3(entry.coords.x, entry.coords.y, entry.coords.z)
        options.radius = entry.radius
        activeZones[entry.id] = lib.zones.sphere(options)
    elseif entry.type == 'box' then
        options.coords = vec3(entry.coords.x, entry.coords.y, entry.coords.z)
        options.size = vec3(entry.size.x, entry.size.y, entry.size.z)
        options.rotation = entry.rotation or 0.0
        activeZones[entry.id] = lib.zones.box(options)
    elseif entry.type == 'poly' then
        options.points = {}

        for _, point in ipairs(entry.points or {}) do
            options.points[#options.points + 1] = vec3(point.x, point.y, point.z)
        end

        options.thickness = entry.thickness
        activeZones[entry.id] = lib.zones.poly(options)
    end
end

local function applyZones(zones)
    clearZones()

    for _, entry in ipairs(zones or {}) do
        if type(entry) == 'table' and type(entry.id) == 'string' then
            createZone(entry)
        end
    end
end

local function refreshZones()
    local response = lib.callback.await('nexa:zones:cb:getAvailable', false)

    if type(response) == 'table' and response.success and response.data ~= nil then
        applyZones(response.data.zones or {})
    end
end

RegisterNetEvent(NEXA_ZONES_EVENTS.refresh, refreshZones)

CreateThread(function()
    Wait(1500)
    refreshZones()
end)
