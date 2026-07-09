local currentPanel = nil
local registeredContexts = {}
local openContextId = nil
local pendingInput = nil
local inputSequence = 0
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
    setUiFocus(currentPanel ~= nil or openContextId ~= nil or pendingInput ~= nil)
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

local function normalizeContextOption(option, index)
    if type(option) ~= 'table' then
        return nil
    end

    local title = NexaUiSanitizeText(option.title or option.label, 64)

    if title == nil then
        return nil
    end

    return {
        index = index,
        title = title,
        description = NexaUiSanitizeText(option.description or '', 128),
        icon = NexaUiSanitizeText(option.icon or '', 64),
        disabled = option.disabled == true,
        keepOpen = option.keepOpen == true
    }
end

local function normalizeContext(context)
    if type(context) ~= 'table' or type(context.id) ~= 'string' or context.id == '' or type(context.options) ~= 'table' then
        return nil
    end

    local options = {}

    for index, option in ipairs(context.options) do
        local normalizedOption = normalizeContextOption(option, index)

        if normalizedOption ~= nil then
            options[#options + 1] = normalizedOption
        end
    end

    if #options == 0 then
        return nil
    end

    return {
        id = context.id,
        title = NexaUiSanitizeText(context.title or NexaUiLocale.menuTitle, 64),
        options = options
    }
end

function registerContext(context)
    local normalizedContext = normalizeContext(context)

    if normalizedContext == nil then
        return false
    end

    registeredContexts[normalizedContext.id] = {
        raw = context,
        nui = normalizedContext
    }

    return true
end

function showContext(id)
    local context = registeredContexts[id]

    if context == nil then
        return false
    end

    openContextId = id
    refreshUiFocus()

    sendUiMessage(NEXA_UI_MESSAGE_TYPES.contextOpen, {
        context = context.nui,
        locale = NexaUiLocale,
        theme = getTheme()
    })

    return true
end

function hideContext(force)
    if openContextId == nil and force ~= true then
        return false
    end

    openContextId = nil
    sendUiMessage(NEXA_UI_MESSAGE_TYPES.contextClose)
    refreshUiFocus()

    return true
end

function getOpenContextMenu()
    return openContextId
end

local function normalizeInputField(field, index)
    if type(field) ~= 'table' then
        return nil
    end

    local fieldType = field.type or 'input'

    if fieldType ~= 'input' and fieldType ~= 'number' and fieldType ~= 'textarea' and fieldType ~= 'checkbox' and fieldType ~= 'select' then
        fieldType = 'input'
    end

    local options = {}

    if fieldType == 'select' and type(field.options) == 'table' then
        for optionIndex, option in ipairs(field.options) do
            if type(option) == 'table' then
                options[#options + 1] = {
                    label = NexaUiSanitizeText(option.label or tostring(option.value or optionIndex), 64) or tostring(optionIndex),
                    value = option.value
                }
            end
        end
    end

    return {
        index = index,
        type = fieldType,
        label = NexaUiSanitizeText(field.label or ('Feld ' .. index), 64) or ('Feld ' .. index),
        description = NexaUiSanitizeText(field.description or '', 128),
        required = field.required == true,
        min = tonumber(field.min),
        max = tonumber(field.max),
        default = field.default,
        options = options
    }
end

local function normalizeInputDialog(title, fields, options)
    if type(fields) ~= 'table' then
        return nil
    end

    local normalizedFields = {}

    for index, field in ipairs(fields) do
        local normalizedField = normalizeInputField(field, index)

        if normalizedField ~= nil then
            normalizedFields[#normalizedFields + 1] = normalizedField
        end
    end

    if #normalizedFields == 0 then
        return nil
    end

    options = options or {}

    return {
        title = NexaUiSanitizeText(title or NexaUiLocale.panelTitle, 64) or NexaUiLocale.panelTitle,
        fields = normalizedFields,
        submitLabel = NexaUiSanitizeText(options.submitLabel or NexaUiLocale.inputSubmit, 32) or NexaUiLocale.inputSubmit,
        cancelLabel = NexaUiSanitizeText(options.cancelLabel or NexaUiLocale.cancel, 32) or NexaUiLocale.cancel
    }
end

local function resolveInput(value)
    local current = pendingInput

    if current == nil then
        return
    end

    pendingInput = nil
    current.promise:resolve(value)
    sendUiMessage(NEXA_UI_MESSAGE_TYPES.inputClose)
    refreshUiFocus()
end

function inputDialog(title, fields, options)
    if pendingInput ~= nil then
        return nil
    end

    local dialog = normalizeInputDialog(title, fields, options or {})

    if dialog == nil then
        return nil
    end

    inputSequence = inputSequence + 1
    dialog.id = ('input_%s'):format(inputSequence)

    pendingInput = {
        id = dialog.id,
        promise = promise.new()
    }

    refreshUiFocus()

    sendUiMessage(NEXA_UI_MESSAGE_TYPES.inputOpen, {
        dialog = dialog,
        locale = NexaUiLocale,
        theme = getTheme()
    })

    SetTimeout(tonumber(options and options.timeout) or NexaUiClientConfig.inputTimeoutMs, function()
        if pendingInput ~= nil and pendingInput.id == dialog.id then
            resolveInput(nil)
        end
    end)

    return Citizen.Await(pendingInput.promise)
end

function closeInputDialog()
    if pendingInput == nil then
        return false
    end

    resolveInput(nil)
    return true
end

function NexaUiHandleContextSelect(data)
    local contextId = type(data) == 'table' and data.contextId or nil
    local optionIndex = type(data) == 'table' and tonumber(data.index) or nil

    if contextId == nil or optionIndex == nil or contextId ~= openContextId then
        return false
    end

    local context = registeredContexts[contextId]
    local option = context and context.raw and context.raw.options and context.raw.options[optionIndex] or nil

    if type(option) ~= 'table' or option.disabled == true then
        return false
    end

    if type(option.onSelect) == 'function' then
        option.onSelect(option.args)
    end

    if type(option.event) == 'string' then
        TriggerEvent(option.event, option.args)
    end

    if type(option.serverEvent) == 'string' then
        TriggerServerEvent(option.serverEvent, option.args)
    end

    if option.keepOpen ~= true then
        hideContext(true)
    end

    return true
end

function NexaUiHandleInputSubmit(data)
    if pendingInput == nil or type(data) ~= 'table' or data.id ~= pendingInput.id then
        return false
    end

    resolveInput(type(data.values) == 'table' and data.values or nil)
    return true
end

function NexaUiHandleInputCancel(data)
    if pendingInput == nil then
        return false
    end

    if type(data) == 'table' and data.id ~= nil and data.id ~= pendingInput.id then
        return false
    end

    resolveInput(nil)
    return true
end

function NexaUiHandleCloseRequest()
    closeInputDialog()
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
                    title = 'Deaktiviert',
                    description = 'Diese Option ist gesperrt.',
                    disabled = true
                }
            }
        })
        showContext('nexa_demo_context')
    end, false)

    RegisterCommand('nexaui_input', function()
        local result = inputDialog('Nexa Eingabe', {
            {
                type = 'input',
                label = 'Name',
                required = true
            },
            {
                type = 'number',
                label = 'Betrag',
                min = 0
            },
            {
                type = 'checkbox',
                label = 'Bestaetigt'
            }
        })

        notify({
            title = 'Nexa',
            message = result and 'Eingabe gesendet.' or 'Eingabe abgebrochen.',
            type = result and 'success' or 'warning'
        })
    end, false)
end
