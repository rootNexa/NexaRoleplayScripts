local currentPanel = nil
local identitySpawnCompletedAt = nil

local function getRenderingCamState()
    local success, renderingCam = pcall(function()
        return GetRenderingCam()
    end)

    return success and renderingCam or 'unavailable'
end

local function traceUiVisual(eventName, metadata)
    local payload = metadata or {}
    payload.resource = GetCurrentResourceName()
    payload.event = eventName
    payload.gameTimer = GetGameTimer()
    payload.identitySpawnMarker = identitySpawnCompletedAt and 'after' or 'before_or_unknown'
    payload.afterIdentitySpawnCompletedAt = identitySpawnCompletedAt
    payload.currentPanelOpen = currentPanel ~= nil
    payload.screenFadedIn = IsScreenFadedIn()
    payload.screenFadedOut = IsScreenFadedOut()
    payload.screenFadingIn = IsScreenFadingIn()
    payload.screenFadingOut = IsScreenFadingOut()
    payload.renderingCam = getRenderingCamState()

    print(('[nexa_black_trace] %s'):format(json.encode(payload)))
end

AddEventHandler('nexa:identity:client:spawnPreparedCompleted', function(payload)
    identitySpawnCompletedAt = payload and payload.gameTimer or GetGameTimer()
    traceUiVisual('nexa:identity:client:spawnPreparedCompleted observed')
end)

local function sendUiMessage(messageType, payload)
    traceUiVisual(('SendNUIMessage:%s'):format(messageType), {
        fullscreenShell = messageType == NEXA_UI_MESSAGE_TYPES.openPanel or currentPanel ~= nil,
        messageType = messageType
    })

    SendNUIMessage({
        type = messageType,
        payload = payload or {}
    })
end

local function setUiFocus(enabled)
    if NexaUiClientConfig.enableFocusOnPanelOpen then
        traceUiVisual(('SetNuiFocus(%s,%s)'):format(tostring(enabled), tostring(enabled)), {
            reason = 'nexa_ui panel focus'
        })
        SetNuiFocus(enabled, enabled)
    end
end

function open(payload)
    traceUiVisual('event/export:nexa_ui open before', {
        fullscreenNui = true,
        panelTitle = payload and payload.title or nil,
        mode = payload and payload.mode or nil
    })

    currentPanel = payload or {}
    setUiFocus(true)

    sendUiMessage(NEXA_UI_MESSAGE_TYPES.openPanel, {
        panel = currentPanel,
        locale = NexaUiLocale,
        theme = getTheme()
    })

    traceUiVisual('fullscreen shell/panel open after', {
        fullscreenNui = true,
        panelTitle = currentPanel and currentPanel.title or nil,
        mode = currentPanel and currentPanel.mode or nil
    })

    return true
end

function close()
    traceUiVisual('event/export:nexa_ui close before', {
        fullscreenNui = currentPanel ~= nil
    })

    currentPanel = nil
    setUiFocus(false)
    sendUiMessage(NEXA_UI_MESSAGE_TYPES.closePanel)

    traceUiVisual('fullscreen shell/panel close after', {
        fullscreenNui = false
    })

    return true
end

function notify(payload)
    traceUiVisual('event/export:nexa_ui notify', {
        fullscreenNui = currentPanel ~= nil
    })

    local notification = NexaUiNormalizeNotification(payload)

    if notification == nil then
        return false
    end

    lib.notify({
        title = notification.title,
        description = notification.message,
        type = notification.type,
        duration = notification.duration
    })

    sendUiMessage(NEXA_UI_MESSAGE_TYPES.notify, notification)

    return true
end

function menu(payload)
    traceUiVisual('event/export:nexa_ui menu before', {
        fullscreenNui = true
    })

    local normalizedMenu = NexaUiNormalizeMenu(payload)

    if normalizedMenu == nil then
        notify({
            message = NexaUiLocale.invalidPayload,
            type = 'error'
        })
        return false
    end

    open({
        title = normalizedMenu.title,
        mode = 'menu'
    })

    sendUiMessage(NEXA_UI_MESSAGE_TYPES.menu, normalizedMenu)

    return true
end

function getTheme()
    return NexaUiCopyTable(NexaUiTheme)
end

function getLocale()
    return NexaUiCopyTable(NexaUiLocale)
end

RegisterNetEvent(NEXA_UI_EVENTS.open, open)
RegisterNetEvent(NEXA_UI_EVENTS.close, close)
RegisterNetEvent(NEXA_UI_EVENTS.notify, notify)
RegisterNetEvent(NEXA_UI_EVENTS.menu, menu)

exports('open', open)
exports('close', close)
exports('notify', notify)
exports('menu', menu)
exports('getTheme', getTheme)
exports('getLocale', getLocale)

if NexaUiConfig.allowDemoInteractions then
    RegisterCommand('nexaui', function()
        notify({
            title = 'Nexa',
            message = 'UI-System bereit.',
            type = 'success'
        })
    end, false)
end
