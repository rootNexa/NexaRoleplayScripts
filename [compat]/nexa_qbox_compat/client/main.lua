local RESOURCE = GetCurrentResourceName()
local openedIdentity = false
local identitySpawnCompletedAt = nil

local function traceAfterIdentitySpawn(eventName, metadata)
    if identitySpawnCompletedAt == nil then
        return
    end

    local payload = metadata or {}
    payload.resource = RESOURCE
    payload.event = eventName
    payload.gameTimer = GetGameTimer()
    payload.afterIdentitySpawnCompletedAt = identitySpawnCompletedAt

    print(('[nexa_post_spawn_trace] %s'):format(json.encode(payload)))
end

AddEventHandler('nexa:identity:client:spawnPreparedCompleted', function(payload)
    identitySpawnCompletedAt = payload and payload.gameTimer or GetGameTimer()
    traceAfterIdentitySpawn('nexa:identity:client:spawnPreparedCompleted observed')
end)

local function vectorToLog(coords)
    if coords == nil then
        return nil
    end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
end

local function safeNative(label, callback)
    local success, result = pcall(callback)

    if not success then
        return ('unavailable: %s'):format(result)
    end

    return result
end

local function isLoadingShutdownSkipped()
    return GetConvar('nexa:identitySkipLoadingShutdown', 'false') == 'true'
end

local function transitionVector(label, callback)
    local value = safeNative(label, callback)

    if type(value) == 'string' then
        return value
    end

    return vectorToLog(value)
end

local function traceLoadingTransition(eventName, metadata)
    local payload = metadata or {}
    payload.resource = RESOURCE
    payload.event = eventName
    payload.gameTimer = GetGameTimer()
    payload.identitySpawnMarker = identitySpawnCompletedAt and 'after' or 'before_or_unknown'
    payload.identitySpawnCompletedAt = identitySpawnCompletedAt
    payload.skipLoadingShutdown = isLoadingShutdownSkipped()
    payload.screenFadedIn = IsScreenFadedIn()
    payload.screenFadedOut = IsScreenFadedOut()
    payload.screenFadingIn = IsScreenFadingIn()
    payload.screenFadingOut = IsScreenFadingOut()
    payload.renderingCam = safeNative('GetRenderingCam', function()
        return GetRenderingCam()
    end)
    payload.gameplayCamCoord = transitionVector('GetGameplayCamCoord', function()
        return GetGameplayCamCoord()
    end)
    payload.finalRenderedCamCoord = transitionVector('GetFinalRenderedCamCoord', function()
        return GetFinalRenderedCamCoord()
    end)
    payload.pedCoords = transitionVector('GetEntityCoords(PlayerPedId())', function()
        return GetEntityCoords(PlayerPedId())
    end)

    print(('[nexa_loading_trace] %s'):format(json.encode(payload)))
end

local function tracedShutdownLoadingScreen(reason)
    traceLoadingTransition(('ShutdownLoadingScreen before: %s'):format(reason))

    if isLoadingShutdownSkipped() then
        traceLoadingTransition(('ShutdownLoadingScreen skipped: %s'):format(reason))
        return false
    end

    ShutdownLoadingScreen()
    traceLoadingTransition(('ShutdownLoadingScreen after: %s'):format(reason))

    return true
end

local function tracedShutdownLoadingScreenNui(reason)
    traceLoadingTransition(('ShutdownLoadingScreenNui before: %s'):format(reason))

    if isLoadingShutdownSkipped() then
        traceLoadingTransition(('ShutdownLoadingScreenNui skipped: %s'):format(reason))
        return false
    end

    ShutdownLoadingScreenNui()
    traceLoadingTransition(('ShutdownLoadingScreenNui after: %s'):format(reason))

    return true
end

local function tracedDoScreenFadeIn(duration, reason)
    traceLoadingTransition(('DoScreenFadeIn before: %s'):format(reason), {
        duration = duration
    })
    DoScreenFadeIn(duration)
    traceLoadingTransition(('DoScreenFadeIn after: %s'):format(reason), {
        duration = duration
    })
end

local function logInfo(message)
    print(('[%s] %s'):format(RESOURCE, message))
end

local function closeLoadingScreens()
    traceAfterIdentitySpawn('closeLoadingScreens before ShutdownLoadingScreen', {
        screenFadedIn = IsScreenFadedIn(),
        screenFadedOut = IsScreenFadedOut()
    })

    tracedShutdownLoadingScreen('nexa_qbox_compat closeLoadingScreens')
    traceAfterIdentitySpawn('ShutdownLoadingScreen')

    tracedShutdownLoadingScreenNui('nexa_qbox_compat closeLoadingScreens')
    traceAfterIdentitySpawn('ShutdownLoadingScreenNui')

    if IsScreenFadedOut() then
        traceAfterIdentitySpawn('DoScreenFadeIn(500) before')
        tracedDoScreenFadeIn(500, 'nexa_qbox_compat closeLoadingScreens')
        traceAfterIdentitySpawn('DoScreenFadeIn(500) after')
    end
end

local function waitForNexaIdentity()
    while GetResourceState('nexa_identity') ~= 'started' do
        Wait(250)
    end
end

local function openNexaIdentityManager()
    traceAfterIdentitySpawn('openNexaIdentityManager')

    if openedIdentity then
        traceAfterIdentitySpawn('openNexaIdentityManager skipped openedIdentity')
        return
    end

    openedIdentity = true
    closeLoadingScreens()
    waitForNexaIdentity()
    TriggerEvent('nexa:identity:client:openManager')
    logInfo('Opened Nexa Identity manager for external Qbox character flow.')
end

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(250)
    end

    pcall(function()
        exports.spawnmanager:setAutoSpawn(false)
    end)

    Wait(500)
    openNexaIdentityManager()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    traceAfterIdentitySpawn('QBCore:Client:OnPlayerLoaded')
    openedIdentity = true
end)

RegisterNetEvent('qbx_core:client:spawnNoApartments', function()
    traceAfterIdentitySpawn('qbx_core:client:spawnNoApartments observed', {
        watchedResource = 'qbx_core',
        risk = 'DoScreenFadeOut/DoScreenFadeIn/player-loaded path'
    })
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    traceAfterIdentitySpawn('qbx_core:client:playerLoggedOut observed', {
        watchedResource = 'qbx_core',
        risk = 'character selection preview flow'
    })
end)

RegisterNetEvent('qb-spawn:client:setupSpawns', function()
    traceAfterIdentitySpawn('qb-spawn:client:setupSpawns observed', {
        watchedResource = 'qbx_spawn',
        risk = 'Scaleform/map camera/radar hidden path'
    })
end)

RegisterNetEvent('qb-spawn:client:openUI', function()
    traceAfterIdentitySpawn('qb-spawn:client:openUI observed', {
        watchedResource = 'qbx_spawn',
        risk = 'legacy spawn UI entrypoint'
    })
end)

RegisterNetEvent('apartments:client:setupSpawnUI', function()
    traceAfterIdentitySpawn('apartments:client:setupSpawnUI observed', {
        watchedResource = 'qbx_core',
        risk = 'alternate Qbox spawn UI entrypoint'
    })
end)
