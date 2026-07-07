local phoneVisible = false
local phoneSnapshot = {}

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
    local response = lib.callback.await(NexaPhoneConfig.snapshotCallback, false)

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
    if lib and lib.notify then
        lib.notify({
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
    local response = lib.callback.await(NexaPhoneConfig.saveNoteCallback, false, payload or {})

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
    local response = lib.callback.await(NexaPhoneConfig.sendMessageCallback, false, payload or {})

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
