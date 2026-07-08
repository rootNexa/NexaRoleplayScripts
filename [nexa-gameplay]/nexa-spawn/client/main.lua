local REQUEST_EVENT = 'nexa-spawn:server:requestInitialSpawn'
local APPROVED_EVENT = 'nexa-spawn:client:spawnApproved'

local requestedInitialSpawn = false
local completedInitialSpawn = false

local function log(level, message)
    print(('[nexa-spawn] [%s] %s'):format(level, message))
end

local function waitForNetworkSession()
    while not NetworkIsSessionStarted() do
        Wait(250)
    end
end

local function requestInitialSpawn()
    if requestedInitialSpawn or completedInitialSpawn then
        return
    end

    requestedInitialSpawn = true
    TriggerServerEvent(REQUEST_EVENT)
end

local function applySpawn(spawn)
    if completedInitialSpawn then
        return
    end

    if type(spawn) ~= 'table' then
        log('warn', 'Spawn approval ignored: invalid payload.')
        return
    end

    local x = tonumber(spawn.x)
    local y = tonumber(spawn.y)
    local z = tonumber(spawn.z)
    local heading = tonumber(spawn.heading) or 0.0

    if not x or not y or not z then
        log('warn', 'Spawn approval ignored: invalid coordinates.')
        return
    end

    DoScreenFadeOut(250)

    local timeout = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < timeout do
        Wait(0)
    end

    local playerId = PlayerId()
    local playerPed = PlayerPedId()

    RequestCollisionAtCoord(x, y, z)
    NetworkResurrectLocalPlayer(x, y, z, heading, true, true, false)
    playerPed = PlayerPedId()
    SetEntityCoordsNoOffset(playerPed, x, y, z, false, false, false)
    SetEntityHeading(playerPed, heading)

    local collisionTimeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(playerPed) and GetGameTimer() < collisionTimeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    ClearPedTasksImmediately(playerPed)
    SetEntityVisible(playerPed, true, false)
    FreezeEntityPosition(playerPed, false)
    SetPlayerControl(playerId, true, 0)
    DoScreenFadeIn(500)

    completedInitialSpawn = true
    log('info', 'Initial development spawn completed.')
end

RegisterNetEvent(APPROVED_EVENT, function(spawn)
    applySpawn(spawn)
end)

CreateThread(function()
    waitForNetworkSession()
    Wait(1000)
    requestInitialSpawn()
end)
