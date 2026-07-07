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

    local response = lib.callback.await('nexa:npcs:cb:getAvailable', false)

    if type(response) == 'table' and response.success and response.data ~= nil then
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
