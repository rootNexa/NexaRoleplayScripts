RegisterNetEvent(NEXA_FACTIONS_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    lib.notify({
        title = 'Fraktion',
        description = response.message,
        type = response.success and 'success' or 'error'
    })
end)

local function openFactionMenu()
    local overview = lib.callback.await('nexa:factions_core:cb:getOverview', false, {})

    if overview == nil then
        return
    end

    if not overview.success then
        lib.notify({
            title = 'Fraktion',
            description = overview.message,
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

    lib.registerContext({
        id = 'nexa_factions_core_menu',
        title = 'Fraktion',
        options = {
            {
                title = 'Status',
                description = description,
                readOnly = true
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
                    local input = lib.inputDialog('Callsign', {
                        {
                            type = 'input',
                            label = 'Callsign',
                            required = false,
                            max = NexaFactionsConfig.maxCallsignLength
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

    lib.showContext('nexa_factions_core_menu')
end

RegisterCommand(NexaFactionsConfig.commandName, function()
    if not NexaFactionsClient.enableOxContext then
        return
    end

    openFactionMenu()
end, false)
