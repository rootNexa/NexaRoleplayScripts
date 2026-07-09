local mapRegistryCache = {}

local function applyMaps(maps)
    mapRegistryCache = {}

    for _, entry in ipairs(maps or {}) do
        if type(entry) == 'table' and type(entry.id) == 'string' then
            mapRegistryCache[entry.id] = entry
        end
    end
end

local function refreshMaps()
    if not NexaMapsClient.cacheEnabled then
        return
    end

    local mapsRequest = promise.new()
    local request = exports.nexa_api:TriggerServerCallback('nexa:maps:cb:list', {}, function(response)
        mapsRequest:resolve(response)
    end, NexaMapsClient.callbackTimeoutMs)

    if type(request) == 'table' and request.ok == false then
        return
    end

    local response = Citizen.Await(mapsRequest)

    if type(response) == 'table' and response.ok == true and response.data ~= nil then
        applyMaps(response.data.maps or {})
    end
end

local function getCachedMap(mapId)
    return mapRegistryCache[mapId]
end

RegisterNetEvent(NEXA_MAPS_EVENTS.refresh, refreshMaps)

CreateThread(function()
    Wait(1500)
    refreshMaps()
end)

exports('getCachedMap', getCachedMap)
