local identitySpawnCompletedAt = nil

local function traceAfterIdentitySpawn(eventName, metadata)
    if identitySpawnCompletedAt == nil then
        return
    end

    local payload = metadata or {}
    payload.resource = GetCurrentResourceName()
    payload.event = eventName
    payload.gameTimer = GetGameTimer()
    payload.afterIdentitySpawnCompletedAt = identitySpawnCompletedAt
    payload.fullscreenNui = false

    print(('[nexa_post_spawn_trace] %s'):format(json.encode(payload)))
end

AddEventHandler('nexa:identity:client:spawnPreparedCompleted', function(payload)
    identitySpawnCompletedAt = payload and payload.gameTimer or GetGameTimer()
    traceAfterIdentitySpawn('nexa:identity:client:spawnPreparedCompleted observed nui')
end)

RegisterNUICallback('nexaHudReady', function(_, cb)
    traceAfterIdentitySpawn('NUICallback:nexaHudReady')

    cb({
        success = true
    })
end)
