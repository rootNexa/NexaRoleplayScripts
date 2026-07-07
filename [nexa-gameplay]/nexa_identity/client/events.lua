RegisterNetEvent('nexa:identity:client:requestResult', function(response)
    if response == nil then
        return
    end

    lib.notify({
        title = 'Charakterverwaltung',
        description = response.message or 'Der Vorgang konnte nicht abgeschlossen werden.',
        type = response.success and 'success' or 'error'
    })
end)

local function debugLog(message, metadata)
    if GetConvar('nexa:identityDebug', 'false') ~= 'true' then
        return
    end

    print(('[nexa_identity] %s %s'):format(message, metadata and json.encode(metadata) or ''))
end

local function postSpawnTrace(eventName, metadata)
    local payload = metadata or {}
    payload.resource = GetCurrentResourceName()
    payload.event = eventName
    payload.gameTimer = GetGameTimer()

    print(('[nexa_post_spawn_trace] %s'):format(json.encode(payload)))
end

local function isDebugEnabled()
    return GetConvar('nexa:identityDebug', 'false') == 'true'
end

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
    payload.resource = GetCurrentResourceName()
    payload.event = eventName
    payload.gameTimer = GetGameTimer()
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

local function tracedDoScreenFadeOut(duration, reason)
    traceLoadingTransition(('DoScreenFadeOut before: %s'):format(reason), {
        duration = duration
    })
    DoScreenFadeOut(duration)
    traceLoadingTransition(('DoScreenFadeOut after: %s'):format(reason), {
        duration = duration
    })
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

local function getNuiCleanupState()
    return {
        keepInput = safeNative('IsNuiFocusKeepingInput', function()
            return IsNuiFocusKeepingInput()
        end),
        openContext = lib.getOpenContextMenu and lib.getOpenContextMenu() or nil
    }
end

local function getVisualRecoveryState(label)
    return {
        label = label,
        screenFadedIn = IsScreenFadedIn(),
        screenFadedOut = IsScreenFadedOut(),
        screenFadingIn = IsScreenFadingIn(),
        screenFadingOut = IsScreenFadingOut(),
        frontendFading = safeNative('IsFrontendFading', function()
            return IsFrontendFading()
        end),
        pauseMenuActive = IsPauseMenuActive(),
        nuiFocused = IsNuiFocused(),
        nuiFocusKeepingInput = safeNative('IsNuiFocusKeepingInput', function()
            return IsNuiFocusKeepingInput()
        end),
        radarHidden = IsRadarHidden(),
        gameplayCamRendering = safeNative('IsGameplayCamRendering', function()
            return IsGameplayCamRendering()
        end),
        renderingCam = safeNative('GetRenderingCam', function()
            return GetRenderingCam()
        end)
    }
end

local function logVisualRecoveryState(reason, phase, force)
    local metadata = getVisualRecoveryState(('%s %s'):format(reason, phase))

    if force then
        print(('[nexa_identity] visual recovery %s %s'):format(phase, json.encode(metadata)))
    else
        debugLog(('visual recovery %s'):format(phase), metadata)
    end
end

local function applyVisualOverlayCleanup(reason, fadeDuration, forceLog)
    fadeDuration = fadeDuration or 1000

    logVisualRecoveryState(reason, 'before cleanup', forceLog)

    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    AnimpostfxStopAll()

    pcall(function()
        SetFrontendActive(false)
    end)

    SetPauseMenuActive(false)
    DisplayHud(true)
    DisplayRadar(true)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    if IsScreenFadedOut() or IsScreenFadingOut() then
        tracedDoScreenFadeIn(fadeDuration, reason)
        debugLog('13 DoScreenFadeIn', {
            reason = reason,
            duration = fadeDuration
        })
    end

    local fadeTimeout = GetGameTimer() + fadeDuration + 1000

    while not IsScreenFadedIn() and GetGameTimer() < fadeTimeout do
        Wait(50)
    end

    if not IsScreenFadedIn() then
        tracedDoScreenFadeIn(1000, ('%s retry'):format(reason))
        debugLog('13 DoScreenFadeIn', {
            reason = ('%s retry'):format(reason),
            duration = 1000
        })

        local retryTimeout = GetGameTimer() + 2000

        while not IsScreenFadedIn() and GetGameTimer() < retryTimeout do
            Wait(50)
        end
    end

    logVisualRecoveryState(reason, 'after cleanup', forceLog)
end

local lastPlayerSpawnedAt = nil
local lastPlayerSpawnedPayload = nil

AddEventHandler('playerSpawned', function(payload)
    lastPlayerSpawnedAt = GetGameTimer()
    lastPlayerSpawnedPayload = payload

    debugLog('frontend gameplay transition: playerSpawned event received', {
        payload = payload,
        gameTimer = lastPlayerSpawnedAt
    })
end)

local function cleanupIdentityUi(reason)
    debugLog('identity UI cleanup started', {
        reason = reason,
        before = getNuiCleanupState()
    })

    pcall(function()
        lib.hideContext(false)
    end)

    pcall(function()
        lib.closeInputDialog()
    end)

    if GetResourceState('nexa_ui') == 'started' then
        pcall(function()
            exports.nexa_ui:close()
        end)
    end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    debugLog('identity UI cleanup completed', {
        reason = reason,
        after = getNuiCleanupState()
    })
end

local function getFrontendGameplayState(label)
    return {
        label = label,
        networkSessionStarted = NetworkIsSessionStarted(),
        networkGameInProgress = safeNative('NetworkIsGameInProgress', function()
            return NetworkIsGameInProgress()
        end),
        localPlayerLoggedIn = LocalPlayer and LocalPlayer.state and LocalPlayer.state.isLoggedIn or nil,
        playerSpawnedSeen = lastPlayerSpawnedAt ~= nil,
        playerSpawnedAt = lastPlayerSpawnedAt,
        playerSpawnedPayload = lastPlayerSpawnedPayload,
        tutorialSession = safeNative('NetworkIsInTutorialSession', function()
            return NetworkIsInTutorialSession()
        end),
        frontendFading = safeNative('IsFrontendFading', function()
            return IsFrontendFading()
        end),
        pauseMenuActive = IsPauseMenuActive(),
        nuiFocused = IsNuiFocused(),
        nuiFocusKeepingInput = safeNative('IsNuiFocusKeepingInput', function()
            return IsNuiFocusKeepingInput()
        end),
        radarHidden = IsRadarHidden(),
        screenFadedIn = IsScreenFadedIn(),
        screenFadedOut = IsScreenFadedOut(),
        gameplayCamRendering = safeNative('IsGameplayCamRendering', function()
            return IsGameplayCamRendering()
        end),
        renderingCam = safeNative('GetRenderingCam', function()
            return GetRenderingCam()
        end)
    }
end

local function debugFrontendGameplayState(label)
    debugLog(('frontend gameplay transition: %s'):format(label), getFrontendGameplayState(label))
end

local function enforceFrontendGameplayState(reason)
    debugLog('frontend gameplay transition cleanup started', {
        reason = reason,
        before = getFrontendGameplayState('before cleanup')
    })

    NetworkEndTutorialSession()

    local tutorialTimeout = GetGameTimer() + 2000

    while NetworkIsInTutorialSession() and GetGameTimer() < tutorialTimeout do
        Wait(0)
    end

    pcall(function()
        SetFrontendActive(false)
    end)

    SetPauseMenuActive(false)
    SetPlayerControl(PlayerId(), true, 0)
    DisplayHud(true)
    DisplayRadar(true)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    debugLog('frontend gameplay transition cleanup completed', {
        reason = reason,
        after = getFrontendGameplayState('after cleanup')
    })
end

local function getRenderState(label, spawnCoords)
    local ped = PlayerPedId()
    local renderingCam = safeNative('GetRenderingCam', function()
        return GetRenderingCam()
    end)
    local cameraExists = false

    if type(renderingCam) == 'number' and renderingCam ~= -1 then
        cameraExists = safeNative('DoesCamExist', function()
            return DoesCamExist(renderingCam)
        end)
    end

    return {
        label = label,
        ped = ped,
        pedExists = DoesEntityExist(ped),
        pedVisible = IsEntityVisible(ped),
        pedDead = IsEntityDead(ped),
        pedFrozen = safeNative('IsEntityPositionFrozen', function()
            return IsEntityPositionFrozen(ped)
        end),
        pedCoords = vectorToLog(GetEntityCoords(ped)),
        spawnCoords = spawnCoords and {
            x = spawnCoords.x,
            y = spawnCoords.y,
            z = spawnCoords.z,
            heading = spawnCoords.heading
        } or nil,
        networkPlayerActive = NetworkIsPlayerActive(PlayerId()),
        playerSwitchInProgress = IsPlayerSwitchInProgress(),
        screenFadedOut = IsScreenFadedOut(),
        screenFadingOut = IsScreenFadingOut(),
        screenFadedIn = IsScreenFadedIn(),
        renderingCam = renderingCam,
        renderingCamExists = cameraExists,
        gameplayCamRendering = safeNative('IsGameplayCamRendering', function()
            return IsGameplayCamRendering()
        end),
        collisionLoadedAroundPed = HasCollisionLoadedAroundEntity(ped),
        streamingRequests = safeNative('GetNumberOfStreamingRequests', function()
            return GetNumberOfStreamingRequests()
        end)
    }
end

local function debugRenderState(label, spawnCoords)
    debugLog(('render state: %s'):format(label), getRenderState(label, spawnCoords))
end

local function startDebugSpawnMarker(coords)
    if not isDebugEnabled() then
        return
    end

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.85)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Nexa Spawn Debug')
    EndTextCommandSetBlipName(blip)

    CreateThread(function()
        local timeout = GetGameTimer() + 30000

        while GetGameTimer() < timeout do
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.4, 1.4, 1.4, 0, 180, 80, 140, false, false, 2, false, nil, nil, false)
            Wait(0)
        end

        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end

local function enforceGameplayRendering(coords)
    local ped = PlayerPedId()

    ClearFocus()
    SetFocusEntity(ped)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    debugLog('post-spawn render cleanup applied', {
        ped = ped,
        renderingCam = safeNative('GetRenderingCam', function()
            return GetRenderingCam()
        end)
    })
end

local function clearRuntimeState()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    cleanupIdentityUi('spawnPrepared clearRuntimeState')
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    AnimpostfxStopAll()
    DisplayHud(true)
    DisplayRadar(true)
end

local function waitForSpawnReady(coords)
    local timeout = GetGameTimer() + 7000
    local ped = PlayerPedId()

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    while GetGameTimer() < timeout do
        ped = PlayerPedId()

        if NetworkIsPlayerActive(PlayerId()) and DoesEntityExist(ped) and HasCollisionLoadedAroundEntity(ped) then
            return ped, true
        end

        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        Wait(50)
    end

    return ped, false
end

local function finishLoadingToSpawnTransition(coords)
    local ped, ready = waitForSpawnReady(coords)

    traceLoadingTransition('spawnPrepared ready before loading shutdown', {
        spawnReady = ready,
        networkPlayerActive = NetworkIsPlayerActive(PlayerId()),
        pedExists = DoesEntityExist(ped),
        collisionLoadedAroundPed = DoesEntityExist(ped) and HasCollisionLoadedAroundEntity(ped) or false
    })

    SetEntityVisible(ped, true, false)
    debugLog('10 SetEntityVisible(true)', {
        ped = ped,
        phase = 'before loading shutdown'
    })
    FreezeEntityPosition(ped, false)
    debugLog('9 FreezeEntityPosition(false)', {
        ped = ped,
        phase = 'before loading shutdown'
    })
    traceLoadingTransition('RenderScriptCams(false) before loading shutdown')
    RenderScriptCams(false, true, 500, true, true)
    DestroyAllCams(true)
    ClearFocus()
    traceLoadingTransition('RenderScriptCams(false) after loading shutdown')
    debugLog('8 Camera entfernt', {
        phase = 'before loading shutdown'
    })

    tracedShutdownLoadingScreen('spawnPrepared after spawn ready')
    debugLog('11 ShutdownLoadingScreen')
    tracedShutdownLoadingScreenNui('spawnPrepared after spawn ready')
    debugLog('12 ShutdownLoadingScreenNui')

    Wait(0)
    tracedDoScreenFadeIn(1000, 'spawnPrepared after loading shutdown')
    debugLog('13 DoScreenFadeIn', {
        duration = 1000,
        phase = 'after loading shutdown'
    })
end

local function normalizeSpawnCoords(payload)
    if payload == nil or payload.spawn == nil then
        return nil
    end

    local coords = payload.spawn.coords

    if type(coords) ~= 'table' then
        return nil
    end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)

    if x == nil or y == nil or z == nil then
        return nil
    end

    return {
        x = x,
        y = y,
        z = z,
        heading = tonumber(coords.heading) or 0.0
    }
end

local function waitForCollision(ped, coords)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    local timeout = GetGameTimer() + 5000

    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        Wait(50)
    end
end

local function spawnPlayerAt(coords)
    local spawned = pcall(function()
        exports.spawnmanager:spawnPlayer({
            x = coords.x,
            y = coords.y,
            z = coords.z,
            heading = coords.heading
        })
    end)

    local ped = PlayerPedId()

    if not spawned then
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        SetEntityHeading(ped, coords.heading)
    end

    ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    NetworkSetInSpectatorMode(false, ped)
    waitForCollision(ped, coords)

    debugLog('7 Spawn abgeschlossen', {
        usedSpawnManager = spawned,
        pedCoords = vectorToLog(GetEntityCoords(ped))
    })

    return spawned
end

RegisterNetEvent(NEXA_IDENTITY_EVENTS.spawnPrepared, function(payload)
    local coords = normalizeSpawnCoords(payload)

    if coords == nil then
        debugLog('spawnPrepared ignored: invalid spawn payload', payload)
        return
    end

    debugLog('6 Spawn Event gestartet', {
        characterId = payload.character and payload.character.id or nil,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = coords.heading
    })

    tracedDoScreenFadeOut(250, 'spawnPrepared initial fade-out')

    local timeout = GetGameTimer() + 2000

    while not IsScreenFadedOut() and GetGameTimer() < timeout do
        Wait(0)
    end

    clearRuntimeState()
    local usedSpawnManager = spawnPlayerAt(coords)
    startDebugSpawnMarker(coords)
    debugRenderState('after spawnPlayerAt', coords)
    enforceGameplayRendering(coords)
    debugRenderState('after enforceGameplayRendering', coords)
    finishLoadingToSpawnTransition(coords)
    debugRenderState('after loading shutdown fade-in', coords)

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerEvent('playerSpawned', {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = coords.heading
    })
    debugFrontendGameplayState('after loaded events')
    enforceFrontendGameplayState('after loaded events')
    debugFrontendGameplayState('after frontend cleanup')

    applyVisualOverlayCleanup('spawnPrepared post-spawn verify', 1000, false)
    cleanupIdentityUi('spawnPrepared after fade-in')
    enforceFrontendGameplayState('after fade-in')
    debugFrontendGameplayState('after fade-in')
    debugRenderState('after fade-in wait', coords)

    debugLog('spawnPrepared completed', {
        usedSpawnManager = usedSpawnManager,
        fadedIn = not IsScreenFadedOut()
    })

    postSpawnTrace('spawnPrepared completed', {
        usedSpawnManager = usedSpawnManager,
        screenFadedIn = IsScreenFadedIn(),
        screenFadedOut = IsScreenFadedOut(),
        nuiFocused = IsNuiFocused(),
        renderingCam = safeNative('GetRenderingCam', function()
            return GetRenderingCam()
        end)
    })

    TriggerEvent('nexa:identity:client:spawnPreparedCompleted', {
        gameTimer = GetGameTimer()
    })
end)

RegisterNetEvent(NEXA_IDENTITY_EVENTS.openManager, function()
    debugLog('openManager event received')

    if IsScreenFadedOut() then
        tracedShutdownLoadingScreen('openManager faded-out recovery')
        debugLog('11 ShutdownLoadingScreen')
        tracedShutdownLoadingScreenNui('openManager faded-out recovery')
        debugLog('12 ShutdownLoadingScreenNui')
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        RenderScriptCams(false, false, 0, true, true)
        DestroyAllCams(true)
        debugLog('8 Camera entfernt')
        FreezeEntityPosition(PlayerPedId(), false)
        debugLog('9 FreezeEntityPosition(false)', {
            ped = PlayerPedId()
        })
        SetEntityVisible(PlayerPedId(), true, false)
        debugLog('10 SetEntityVisible(true)', {
            ped = PlayerPedId()
        })
        applyVisualOverlayCleanup('openManager faded-out recovery', 1000, false)
    end
end)

RegisterCommand('nexa_fixblack', function()
    CreateThread(function()
        print('[nexa_identity] /nexa_fixblack started')
        logVisualRecoveryState('/nexa_fixblack', 'before cleanup', true)

        tracedDoScreenFadeIn(1000, '/nexa_fixblack')
        ClearTimecycleModifier()
        ClearExtraTimecycleModifier()
        AnimpostfxStopAll()

        pcall(function()
            SetFrontendActive(false)
        end)

        SetPauseMenuActive(false)
        DisplayHud(true)
        DisplayRadar(true)
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)

        Wait(1250)

        logVisualRecoveryState('/nexa_fixblack', 'after cleanup', true)
        print('[nexa_identity] /nexa_fixblack completed')
    end)
end, false)
