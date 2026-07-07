local confirmSequence = 0
local pendingConfirms = {}
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
    payload.screenFadedIn = IsScreenFadedIn()
    payload.screenFadedOut = IsScreenFadedOut()
    payload.screenFadingIn = IsScreenFadingIn()
    payload.screenFadingOut = IsScreenFadingOut()
    payload.renderingCam = getRenderingCamState()

    print(('[nexa_black_trace] %s'):format(json.encode(payload)))
end

AddEventHandler('nexa:identity:client:spawnPreparedCompleted', function(payload)
    identitySpawnCompletedAt = payload and payload.gameTimer or GetGameTimer()
    traceUiVisual('nexa:identity:client:spawnPreparedCompleted observed nui')
end)

local function sendUiMessage(messageType, payload)
    traceUiVisual(('SendNUIMessage:%s'):format(messageType), {
        source = 'nexa_ui nui.lua',
        messageType = messageType,
        fullscreenNui = messageType == NEXA_UI_MESSAGE_TYPES.confirm
    })

    SendNUIMessage({
        type = messageType,
        payload = payload or {}
    })
end

function confirm(payload, callback)
    traceUiVisual('event/export:nexa_ui confirm before', {
        fullscreenNui = true
    })

    local normalizedConfirm = NexaUiNormalizeConfirm(payload)

    if normalizedConfirm == nil then
        if callback ~= nil then
            callback(false)
        end

        return false
    end

    confirmSequence = confirmSequence + 1
    normalizedConfirm.id = ('confirm_%s'):format(confirmSequence)
    pendingConfirms[normalizedConfirm.id] = callback

    open({
        title = normalizedConfirm.title,
        mode = 'confirm'
    })

    sendUiMessage(NEXA_UI_MESSAGE_TYPES.confirm, normalizedConfirm)

    return true
end

RegisterNetEvent(NEXA_UI_EVENTS.confirm, function(payload)
    traceUiVisual(NEXA_UI_EVENTS.confirm)
    confirm(payload)
end)

RegisterNUICallback('nexaUiClose', function(_, cb)
    traceUiVisual('NUICallback:nexaUiClose')
    close()
    cb({
        success = true
    })
end)

RegisterNUICallback('nexaUiConfirmResult', function(data, cb)
    traceUiVisual('NUICallback:nexaUiConfirmResult')
    local dialogId = type(data) == 'table' and data.id or nil
    local confirmed = type(data) == 'table' and data.confirmed == true
    local callback = dialogId and pendingConfirms[dialogId] or nil

    if dialogId ~= nil then
        pendingConfirms[dialogId] = nil
    end

    if callback ~= nil then
        callback(confirmed)
    end

    close()

    cb({
        success = true
    })
end)

RegisterNUICallback('nexaUiMenuSelect', function(data, cb)
    traceUiVisual('NUICallback:nexaUiMenuSelect')
    notify({
        message = NexaUiLocale.actionUnavailable,
        type = 'info'
    })

    cb({
        success = true,
        selected = type(data) == 'table' and data.id or nil
    })
end)

exports('confirm', confirm)
