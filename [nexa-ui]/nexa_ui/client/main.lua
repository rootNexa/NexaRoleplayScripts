local currentPanel = nil
local ContextRegistry = {}
local CurrentContext = nil
local CurrentInputDialog = nil
local InputDialogRequestId = 0
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

local function refreshUiFocus()
    setUiFocus(currentPanel ~= nil or CurrentContext ~= nil)
end

function open(payload)
    traceUiVisual('event/export:nexa_ui open before', {
        fullscreenNui = true,
        panelTitle = payload and payload.title or nil,
        mode = payload and payload.mode or nil
    })

    currentPanel = payload or {}
    refreshUiFocus()

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
    refreshUiFocus()
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

local function normalizeContextForDisplay(context)
    local options = {}

    if type(context.options) == 'table' then
        for optionIndex, option in ipairs(context.options) do
            if type(option) == 'table' then
                options[#options + 1] = {
                    optionIndex = optionIndex,
                    title = NexaUiSanitizeText(option.title or option.label or '', 64) or '',
                    description = NexaUiSanitizeText(option.description or '', 128) or '',
                    disabled = option.disabled == true
                }
            end
        end
    end

    return {
        id = context.id,
        title = NexaUiSanitizeText(context.title or NexaUiLocale.menuTitle, 64) or NexaUiLocale.menuTitle,
        options = options
    }
end

function registerContext(context)
    if type(context) ~= 'table' or type(context.id) ~= 'string' or context.id == '' then
        return false
    end

    ContextRegistry[context.id] = context

    return true
end

function showContext(id)
    if type(id) ~= 'string' or ContextRegistry[id] == nil then
        return false
    end

    CurrentContext = id
    refreshUiFocus()
    sendUiMessage(NEXA_UI_MESSAGE_TYPES.contextOpen, {
        context = normalizeContextForDisplay(ContextRegistry[id]),
        locale = NexaUiLocale,
        theme = getTheme()
    })

    return true
end

function hideContext(force)
    if CurrentContext == nil and force ~= true then
        return false
    end

    CurrentContext = nil
    sendUiMessage(NEXA_UI_MESSAGE_TYPES.contextClose)
    refreshUiFocus()

    return true
end

function getOpenContextMenu()
    return CurrentContext
end

function inputDialog(title, fields, options)
    if type(title) ~= 'string' or type(fields) ~= 'table' then
        return nil
    end

    InputDialogRequestId = InputDialogRequestId + 1
    CurrentInputDialog = {
        id = InputDialogRequestId,
        title = title,
        fields = fields,
        options = options or {}
    }

    setUiFocus(true)
    sendUiMessage(NEXA_UI_MESSAGE_TYPES.inputOpen, {
        id = CurrentInputDialog.id,
        title = title,
        fields = fields,
        options = options or {}
    })

    return nil
end

function closeInputDialog()
    sendUiMessage(NEXA_UI_MESSAGE_TYPES.inputClose)
    CurrentInputDialog = nil
    refreshUiFocus()

    return true
end

function NexaUiHandleContextSelect(data)
    local contextId = type(data) == 'table' and data.contextId or nil
    local optionIndex = type(data) == 'table' and tonumber(data.optionIndex) or nil

    if CurrentContext == nil or contextId ~= CurrentContext or optionIndex == nil then
        return false
    end

    local context = ContextRegistry[CurrentContext]
    local option = context and type(context.options) == 'table' and context.options[optionIndex] or nil

    if type(option) ~= 'table' or option.disabled == true then
        return false
    end

    if type(option.onSelect) == 'function' then
        option.onSelect(option.args)
    end

    if type(option.event) == 'string' and option.event ~= '' then
        TriggerEvent(option.event, option.args)
    end

    if type(option.serverEvent) == 'string' and option.serverEvent ~= '' then
        TriggerServerEvent(option.serverEvent, option.args)
    end

    if option.keepOpen ~= true then
        hideContext(true)
    end

    return true
end

function NexaUiHandleCloseRequest()
    if CurrentInputDialog ~= nil then
        closeInputDialog()
    end

    hideContext(true)
    close()
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
exports('registerContext', registerContext)
exports('showContext', showContext)
exports('hideContext', hideContext)
exports('getOpenContextMenu', getOpenContextMenu)
exports('inputDialog', inputDialog)
exports('closeInputDialog', closeInputDialog)

if NexaUiConfig.allowDemoInteractions then
    RegisterCommand('nexaui', function()
        notify({
            title = 'Nexa',
            message = 'UI-System bereit.',
            type = 'success'
        })
    end, false)

    RegisterCommand('nexaui_context', function()
        registerContext({
            id = 'nexa_demo_context',
            title = 'Nexa Context',
            options = {
                {
                    title = 'Lokale Aktion',
                    description = 'Fuehrt eine lokale Auswahl aus.',
                    onSelect = function()
                        notify({
                            title = 'Nexa',
                            message = 'Context-Auswahl ausgefuehrt.',
                            type = 'success'
                        })
                    end
                },
                {
                    title = 'Offen halten',
                    description = 'Diese Option schliesst das Menue nicht.',
                    keepOpen = true,
                    onSelect = function()
                        notify({
                            title = 'Nexa',
                            message = 'Context bleibt offen.',
                            type = 'info'
                        })
                    end
                },
                {
                    title = 'Deaktiviert',
                    description = 'Diese Option ist gesperrt.',
                    disabled = true
                }
            }
        })

        showContext('nexa_demo_context')
    end, false)
end
