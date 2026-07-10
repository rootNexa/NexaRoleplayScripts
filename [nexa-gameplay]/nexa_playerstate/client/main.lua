local pendingSpawn = nil

local function applySpawn(payload)
    if type(payload) ~= 'table' or type(payload.position) ~= 'table' or type(payload.token) ~= 'string' then
        return
    end

    pendingSpawn = payload
    local position = payload.position
    DoScreenFadeOut(250)

    local timeout = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < timeout do
        Wait(0)
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    RequestCollisionAtCoord(position.x, position.y, position.z)
    NetworkResurrectLocalPlayer(position.x, position.y, position.z, position.heading or 0.0, true, true, false)
    ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, false, false, false)
    SetEntityHeading(ped, position.heading or 0.0)

    local collisionTimeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionTimeout do
        RequestCollisionAtCoord(position.x, position.y, position.z)
        Wait(0)
    end

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    ClearPedTasksImmediately(ped)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    DoScreenFadeIn(500)

    TriggerServerEvent(NEXA_PLAYERSTATE.events.spawnConfirm, {
        token = payload.token,
        characterId = payload.characterId
    })
    pendingSpawn = nil
end

RegisterNetEvent(NEXA_PLAYERSTATE.events.spawnExecute, applySpawn)

CreateThread(function()
    while true do
        Wait(15000)

        if pendingSpawn == nil and NetworkIsSessionStarted() then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            if coords then
                TriggerServerEvent(NEXA_PLAYERSTATE.events.positionSnapshot, {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    heading = GetEntityHeading(ped) or 0.0
                })
            end
        end
    end
end)
