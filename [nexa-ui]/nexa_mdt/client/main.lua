local mdtVisible = false
local mdtSnapshot = {}

local function sendMdtMessage(messageType, payload)
    SendNUIMessage({
        type = messageType,
        payload = payload or {}
    })
end

local function getDesignPayload()
    local theme = {}
    local locale = {}

    if GetResourceState(NexaMdtConfig.designSystemResource) == 'started' then
        theme = exports.nexa_ui:getTheme() or {}
        locale = exports.nexa_ui:getLocale() or {}
    end

    return {
        theme = theme,
        uiLocale = locale,
        mdtLocale = NexaMdtLocale
    }
end

local function setVisible(visible)
    if not NexaMdtClientConfig.enabled then
        return
    end

    mdtVisible = visible == true
    SetNuiFocus(mdtVisible, mdtVisible)
    sendMdtMessage(NEXA_MDT_MESSAGES.visibility, {
        visible = mdtVisible
    })
end

local function showNotice(text, noticeType)
    if lib and lib.notify then
        lib.notify({
            title = NexaMdtLocale.title,
            description = text,
            type = noticeType or 'inform'
        })
    end

    sendMdtMessage(NEXA_MDT_MESSAGES.notice, {
        text = text
    })
end

local function refreshSnapshot()
    local response = lib.callback.await(NexaMdtConfig.snapshotCallback, false)

    if type(response) ~= 'table' or response.success ~= true then
        mdtSnapshot = {}
        sendMdtMessage(NEXA_MDT_MESSAGES.snapshot, mdtSnapshot)
        showNotice(NexaMdtLocale.denied, 'error')
        return false
    end

    mdtSnapshot = response.data or {}
    sendMdtMessage(NEXA_MDT_MESSAGES.snapshot, mdtSnapshot)
    return true
end

local function searchPerson(payload)
    local response = lib.callback.await(NexaMdtConfig.personSearchCallback, false, payload or {})

    if type(response) ~= 'table' or response.success ~= true then
        sendMdtMessage(NEXA_MDT_MESSAGES.searchResult, {
            persons = {}
        })
        showNotice(NexaMdtLocale.denied, 'error')
        return false
    end

    sendMdtMessage(NEXA_MDT_MESSAGES.searchResult, response.data or {
        persons = {}
    })
    return true
end

local function openMdt()
    sendMdtMessage(NEXA_MDT_MESSAGES.init, getDesignPayload())
    refreshSnapshot()
    setVisible(true)
end

local function closeMdt()
    setVisible(false)
end

CreateThread(function()
    sendMdtMessage(NEXA_MDT_MESSAGES.init, getDesignPayload())

    if NexaMdtClientConfig.openCommandEnabled then
        RegisterCommand(NexaMdtClientConfig.openCommand, openMdt, false)
    end
end)

RegisterNetEvent('nexa:mdt:client:open', openMdt)
RegisterNetEvent('nexa:mdt:client:close', closeMdt)

exports('open', openMdt)
exports('close', closeMdt)
exports('setVisible', setVisible)
exports('isVisible', function()
    return mdtVisible
end)
exports('refresh', refreshSnapshot)
exports('searchPerson', searchPerson)
exports('getSnapshot', function()
    return NexaMdtCopyTable(mdtSnapshot)
end)
