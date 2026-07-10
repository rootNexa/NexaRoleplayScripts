local phoneVisible = false
local phoneSnapshot = {}

local function awaitServerCallback(name, payload, timeoutMs)
    local waiter = promise.new()
    local request = exports.nexa_api:TriggerServerCallback(name, payload or {}, function(response)
        waiter:resolve(response)
    end, timeoutMs or NexaPhoneClientConfig.snapshotTimeoutMs or 5000)

    if type(request) == 'table' and request.ok == false then
        return request
    end

    return Citizen.Await(waiter)
end

local function sendPhoneMessage(messageType, payload)
    SendNUIMessage({
        type = messageType,
        payload = payload or {}
    })
end

local function getDesignPayload()
    local theme = {}
    local locale = {}

    if GetResourceState(NexaPhoneConfig.designSystemResource) == 'started' then
        theme = exports.nexa_ui:getTheme() or {}
        locale = exports.nexa_ui:getLocale() or {}
    end

    return {
        theme = theme,
        uiLocale = locale,
        phoneLocale = NexaPhoneLocale
    }
end

local function setVisible(visible)
    if not NexaPhoneClientConfig.enabled then
        return
    end

    phoneVisible = visible == true
    SetNuiFocus(phoneVisible, phoneVisible)
    sendPhoneMessage(NEXA_PHONE_MESSAGES.visibility, {
        visible = phoneVisible
    })
end

local function refreshSnapshot()
    local response = awaitServerCallback(NexaPhoneConfig.snapshotCallback, {})

    if type(response) ~= 'table' or response.success ~= true then
        phoneSnapshot = {}
        sendPhoneMessage(NEXA_PHONE_MESSAGES.snapshot, phoneSnapshot)
        return false
    end

    phoneSnapshot = response.data or {}
    sendPhoneMessage(NEXA_PHONE_MESSAGES.snapshot, phoneSnapshot)

    return true
end

local function openPhone()
    sendPhoneMessage(NEXA_PHONE_MESSAGES.init, getDesignPayload())
    refreshSnapshot()
    setVisible(true)
end

local function closePhone()
    setVisible(false)
end

local function showNotice(text, noticeType)
    if GetResourceState('nexa_ui') == 'started' then
        exports.nexa_ui:notify({
            title = NexaPhoneLocale.title,
            description = text,
            type = noticeType or 'inform'
        })
    end

    sendPhoneMessage(NEXA_PHONE_MESSAGES.notice, {
        text = text
    })
end

local function saveNote(payload)
    local response = awaitServerCallback(NexaPhoneConfig.saveNoteCallback, payload or {})

    if type(response) == 'table' and response.success == true then
        phoneSnapshot = response.data and response.data.snapshot or phoneSnapshot
        sendPhoneMessage(NEXA_PHONE_MESSAGES.snapshot, phoneSnapshot)
        showNotice(NexaPhoneLocale.saved, 'success')
        return true
    end

    showNotice(NexaPhoneLocale.rejected, 'error')
    return false
end

local function sendMessage(payload)
    local response = awaitServerCallback(NexaPhoneConfig.sendMessageCallback, payload or {})

    if type(response) == 'table' and response.success == true then
        phoneSnapshot = response.data and response.data.snapshot or phoneSnapshot
        sendPhoneMessage(NEXA_PHONE_MESSAGES.snapshot, phoneSnapshot)
        showNotice(NexaPhoneLocale.sent, 'success')
        return true
    end

    showNotice(NexaPhoneLocale.rejected, 'error')
    return false
end

CreateThread(function()
    sendPhoneMessage(NEXA_PHONE_MESSAGES.init, getDesignPayload())

    if NexaPhoneClientConfig.openCommandEnabled then
        RegisterCommand(NexaPhoneClientConfig.openCommand, openPhone, false)
    end
end)

RegisterNetEvent('nexa:phone:client:open', openPhone)
RegisterNetEvent('nexa:phone:client:close', closePhone)

exports('open', openPhone)
exports('close', closePhone)
exports('setVisible', setVisible)
exports('isVisible', function()
    return phoneVisible
end)
exports('refresh', refreshSnapshot)
exports('saveNote', saveNote)
exports('sendMessage', sendMessage)
exports('getSnapshot', function()
    return NexaPhoneCopyTable(phoneSnapshot)
end)
