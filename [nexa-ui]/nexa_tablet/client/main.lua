local tabletVisible = false
local tabletApps = {}

local function sendTabletMessage(messageType, payload)
    SendNUIMessage({
        type = messageType,
        payload = payload or {}
    })
end

local function getDesignPayload()
    local theme = {}
    local locale = {}

    if GetResourceState(NexaTabletConfig.designSystemResource) == 'started' then
        theme = exports.nexa_ui:getTheme() or {}
        locale = exports.nexa_ui:getLocale() or {}
    end

    return {
        theme = theme,
        uiLocale = locale,
        tabletLocale = NexaTabletLocale
    }
end

local function setVisible(visible)
    if not NexaTabletClientConfig.enabled then
        return
    end

    tabletVisible = visible == true
    SetNuiFocus(tabletVisible, tabletVisible)
    sendTabletMessage(NEXA_TABLET_MESSAGES.visibility, {
        visible = tabletVisible
    })
end

local function refreshApps()
    local response = lib.callback.await(NexaTabletConfig.appsCallback, false)

    if type(response) ~= 'table' or response.success ~= true then
        tabletApps = {}
        sendTabletMessage(NEXA_TABLET_MESSAGES.apps, {
            apps = tabletApps
        })
        return false
    end

    tabletApps = response.data and response.data.apps or {}
    sendTabletMessage(NEXA_TABLET_MESSAGES.apps, {
        apps = tabletApps
    })

    return true
end

local function openTablet()
    sendTabletMessage(NEXA_TABLET_MESSAGES.init, getDesignPayload())
    refreshApps()
    setVisible(true)
end

local function closeTablet()
    setVisible(false)
end

local function notifyUnavailable()
    if lib and lib.notify then
        lib.notify({
            title = NexaTabletLocale.unavailableTitle,
            description = NexaTabletLocale.unavailableText,
            type = 'inform'
        })
    end

    sendTabletMessage(NEXA_TABLET_MESSAGES.notice, {
        title = NexaTabletLocale.unavailableTitle,
        text = NexaTabletLocale.unavailableText
    })
end

CreateThread(function()
    sendTabletMessage(NEXA_TABLET_MESSAGES.init, getDesignPayload())

    if NexaTabletClientConfig.openCommandEnabled then
        RegisterCommand(NexaTabletClientConfig.openCommand, openTablet, false)
    end
end)

RegisterNetEvent('nexa:tablet:client:open', openTablet)
RegisterNetEvent('nexa:tablet:client:close', closeTablet)

exports('open', openTablet)
exports('close', closeTablet)
exports('setVisible', setVisible)
exports('isVisible', function()
    return tabletVisible
end)
exports('refreshApps', refreshApps)
exports('getApps', function()
    return NexaTabletCopyTable(tabletApps)
end)
exports('notifyUnavailable', notifyUnavailable)
