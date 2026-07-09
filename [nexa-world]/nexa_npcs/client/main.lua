local npcRegistryCache = {}

local function applyNpcs(npcs)
    npcRegistryCache = {}

    for _, npc in ipairs(npcs or {}) do
        if type(npc) == 'table' and type(npc.id) == 'string' then
            npcRegistryCache[npc.id] = npc
        end
    end
end

local function refreshNpcs()
    if not NexaNpcsClient.cacheEnabled then
        return
    end

    local npcsRequest = promise.new()
    local request = exports.nexa_api:TriggerServerCallback('nexa:npcs:cb:getAvailable', {}, function(response)
        npcsRequest:resolve(response)
    end, NexaNpcsClient.callbackTimeoutMs)

    if type(request) == 'table' and request.ok == false then
        return
    end

    local response = Citizen.Await(npcsRequest)

    if type(response) == 'table' and response.ok == true and response.data ~= nil then
        applyNpcs(response.data.npcs or {})
    end
end

local function getCachedNpc(npcId)
    return npcRegistryCache[npcId]
end

RegisterNetEvent(NEXA_NPCS_EVENTS.refresh, refreshNpcs)

CreateThread(function()
    Wait(1500)
    refreshNpcs()
end)

exports('getCachedNpc', getCachedNpc)
