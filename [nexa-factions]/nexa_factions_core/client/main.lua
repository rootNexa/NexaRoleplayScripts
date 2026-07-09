RegisterNetEvent(NEXA_FACTIONS_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    exports.nexa_ui:notify({
        title = 'Fraktion',
        message = response.message,
        type = response.success and 'success' or 'error'
    })
end)

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
            message = error.message or 'Anfrage fehlgeschlagen.',
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

local function openFactionMenu()
    local overview = awaitServerCallback('nexa:factions_core:cb:getOverview', {})

    if overview == nil then
        return
    end

    if not overview.success then
        exports.nexa_ui:notify({
            title = 'Fraktion',
            message = overview.message,
            type = 'error'
        })
        return
    end

    local membership = overview.data and overview.data.membership or nil
    local dutySession = overview.data and overview.data.dutySession or nil
    local description = 'Keine aktive Fraktionsmitgliedschaft.'

    if membership ~= nil then
        description = ('%s | %s'):format(membership.faction.label, membership.grade.label)

        if membership.callsign ~= nil then
            description = ('%s | Callsign %s'):format(description, membership.callsign)
        end
    end

    exports.nexa_ui:registerContext({
        id = 'nexa_factions_core_menu',
        title = 'Fraktion',
        options = {
            {
                title = 'Status',
                description = description,
                disabled = true
            },
            {
                title = dutySession ~= nil and 'Dienst beenden' or 'Dienst starten',
                disabled = membership == nil,
                serverEvent = NEXA_FACTIONS_EVENTS.requestToggleDuty
            },
            {
                title = 'Callsign setzen',
                disabled = membership == nil,
                onSelect = function()
                    local input = exports.nexa_ui:inputDialog('Callsign', {
                        {
                            type = 'input',
                            label = 'Callsign',
                            required = false,
                            maxLength = NexaFactionsConfig.maxCallsignLength
                        }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(NEXA_FACTIONS_EVENTS.requestSetCallsign, {
                        callsign = input[1]
                    })
                end
            }
        }
    })

    exports.nexa_ui:showContext('nexa_factions_core_menu')
end

RegisterCommand(NexaFactionsConfig.commandName, function()
    if not NexaFactionsClient.enableContextMenu then
        return
    end

    openFactionMenu()
end, false)
