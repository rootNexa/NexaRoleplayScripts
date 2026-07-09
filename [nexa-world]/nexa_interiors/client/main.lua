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

    local interiorsRequest = promise.new()
    local request = exports.nexa_api:TriggerServerCallback('nexa:interiors:cb:getAvailable', {}, function(response)
        interiorsRequest:resolve(response)
    end, NexaInteriorsClient.callbackTimeoutMs)

    if type(request) == 'table' and request.ok == false then
        return
    end

    local response = Citizen.Await(interiorsRequest)

    if type(response) == 'table' and response.ok == true and response.data ~= nil then
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
