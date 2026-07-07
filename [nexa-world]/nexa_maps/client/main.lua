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

    local response = lib.callback.await('nexa:maps:cb:list', false, {})

    if type(response) == 'table' and response.success and response.data ~= nil then
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
