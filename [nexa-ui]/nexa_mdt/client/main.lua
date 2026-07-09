local mdtVisible = false
local mdtSnapshot = {}
local currentMdtType = NexaMdtConfig.defaultMdtType or MDT_TYPES.police

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
    if GetResourceState(NexaMdtConfig.designSystemResource) == 'started' then
        exports.nexa_ui:notify({
            title = NexaMdtLocale.title,
            message = text,
            type = noticeType or 'info'
        })
    end

    sendMdtMessage(NEXA_MDT_MESSAGES.notice, {
        text = text
    })
end

local function normalizeCallbackResponse(response)
    if type(response) ~= 'table' then
        return nil
    end

    if response.success ~= nil then
        return response
    end

    if response.ok == true and type(response.data) == 'table' and response.data.success ~= nil then
        return response.data
    end

    if response.ok == false then
        local error = response.error or {}

        return {
            success = false,
            code = error.code,
            message = error.message or NexaMdtLocale.denied,
            meta = error.details
        }
    end

    return response
end

local function awaitServerCallback(name, payload)
    local pending = promise.new()
    local request = exports.nexa_api:TriggerServerCallback(name, payload or {}, function(response)
        pending:resolve(normalizeCallbackResponse(response))
    end)

    if type(request) == 'table' and request.ok == false then
        return normalizeCallbackResponse(request)
    end

    return Citizen.Await(pending)
end

local function refreshSnapshot()
    local response = awaitServerCallback(NexaMdtConfig.snapshotCallback, {
        mdtType = currentMdtType
    })

    if type(response) ~= 'table' or response.success ~= true then
        mdtSnapshot = {}
        sendMdtMessage(NEXA_MDT_MESSAGES.snapshot, mdtSnapshot)
        showNotice(NexaMdtLocale.denied, 'error')
        return false
    end

    mdtSnapshot = response.data or {}
    currentMdtType = mdtSnapshot.mdtType or currentMdtType
    sendMdtMessage(NEXA_MDT_MESSAGES.snapshot, mdtSnapshot)
    return true
end

local function searchPerson(payload)
    payload = payload or {}
    payload.mdtType = payload.mdtType or currentMdtType

    local response = awaitServerCallback(NexaMdtConfig.personSearchCallback, payload)

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
