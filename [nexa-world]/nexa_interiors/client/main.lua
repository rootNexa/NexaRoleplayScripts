local interiorCache = {}

local function applyInteriors(interiors)
    interiorCache = {}

    for _, interior in ipairs(interiors or {}) do
        if type(interior) == 'table' and type(interior.id) == 'string' then
            interiorCache[interior.id] = interior
        end
    end
end

local function refreshInteriors()
    if not NexaInteriorsClient.cacheEnabled then
        return
    end

    local response = lib.callback.await('nexa:interiors:cb:getAvailable', false)

    if type(response) == 'table' and response.success and response.data ~= nil then
        applyInteriors(response.data.interiors or {})
    end
end

local function getCachedInterior(interiorId)
    return interiorCache[interiorId]
end

RegisterNetEvent(NEXA_INTERIORS_EVENTS.refresh, refreshInteriors)

CreateThread(function()
    Wait(1500)
    refreshInteriors()
end)

exports('getCachedInterior', getCachedInterior)
