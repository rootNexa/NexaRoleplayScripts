RegisterNetEvent(NEXA_ILLEGAL_CORE_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    lib.notify({
        title = 'Illegal Core',
        description = response.message,
        type = response.success and 'success' or 'error'
    })
end)

RegisterNetEvent(NEXA_ILLEGAL_CORE_EVENTS.reputationUpdated, function(payload)
    if payload == nil then
        return
    end

    lib.notify({
        title = 'Illegal Core',
        description = 'Reputation wurde aktualisiert.',
        type = 'inform'
    })
end)

RegisterCommand('nexaillegal', function()
    if not NexaIllegalCoreClient.enableOxContext then
        return
    end

    lib.registerContext({
        id = 'nexa_illegal_core_menu',
        title = 'Illegal Core',
        options = {
            {
                title = 'Status laden',
                onSelect = function()
                    lib.callback.await('nexa:illegal_core:cb:getSnapshot', false, {})
                end
            },
            {
                title = 'Kontakt pruefen',
                onSelect = function()
                    local input = lib.inputDialog('Illegaler Kontakt', {
                        {
                            type = 'checkbox',
                            label = 'Kontakt anfragen',
                            required = true
                        }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(NEXA_ILLEGAL_CORE_EVENTS.requestContact, {})
                end
            }
        }
    })

    lib.showContext('nexa_illegal_core_menu')
end, false)
