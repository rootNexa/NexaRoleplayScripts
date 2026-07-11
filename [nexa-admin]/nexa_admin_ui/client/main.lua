local isOpen = false
local currentSection = NexaAdminUiConfig.defaultSection

local function requestCallback(name, payload)
    local ok, result = pcall(function()
        if exports.nexa_api and exports.nexa_api.ClientCallbackAwait then
            return exports.nexa_api:ClientCallbackAwait(name, payload or {}, 5000)
        end

        if exports.nexa_api and exports.nexa_api.TriggerServerCallback then
            local pending = promise.new()
            exports.nexa_api:TriggerServerCallback(name, payload or {}, function(response)
                pending:resolve(response)
            end, 5000)
            return Citizen.Await(pending)
        end

        return nil
    end)

    if ok then
        return result
    end

    return nil
end

local function notify(message, notificationType)
    if exports.nexa_ui and exports.nexa_ui.notify then
        exports.nexa_ui:notify({
            title = 'Nexa Admin',
            message = message,
            type = notificationType or 'info'
        })
    end
end

local function buildStaticPayload()
    return {
        section = currentSection,
        sections = NexaAdminUiConfig.sections,
        refreshMs = NexaAdminUiConfig.refreshMs
    }
end

local function sendAdminMessage(messageType, payload)
    SendNUIMessage({
        type = messageType,
        payload = payload or {}
    })
end

local function collectDashboard()
    return {
        readiness = requestCallback('nexa:beta:cb:getReadiness', {}),
        health = requestCallback('nexa:beta:cb:collectHealth', {}),
        creators = requestCallback('nexa:beta:cb:listCreators', {})
    }
end

function RefreshNexaAdminUi()
    sendAdminMessage('admin:data', collectDashboard())
end

function OpenNexaAdminUi(section)
    currentSection = type(section) == 'string' and section or NexaAdminUiConfig.defaultSection
    isOpen = true
    SetNuiFocus(true, true)
    sendAdminMessage('admin:open', buildStaticPayload())
    RefreshNexaAdminUi()

    return true
end

function CloseNexaAdminUi()
    if not isOpen then
        return false
    end

    isOpen = false
    SetNuiFocus(false, false)
    sendAdminMessage('admin:close', {})

    return true
end

RegisterCommand(NexaAdminUiConfig.command, function()
    if isOpen then
        CloseNexaAdminUi()
        return
    end

    OpenNexaAdminUi()
end, false)

RegisterNetEvent('nexa:admin_ui:client:open', OpenNexaAdminUi)
RegisterNetEvent('nexa:admin_ui:client:close', CloseNexaAdminUi)

exports('open', OpenNexaAdminUi)
exports('close', CloseNexaAdminUi)
exports('refresh', RefreshNexaAdminUi)

CreateThread(function()
    while true do
        Wait(NexaAdminUiConfig.refreshMs)

        if isOpen then
            RefreshNexaAdminUi()
        end
    end
end)
