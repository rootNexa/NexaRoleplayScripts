RegisterNetEvent(NEXA_DISPATCH_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    lib.notify({
        title = 'Dispatch',
        description = response.message,
        type = response.success and 'success' or 'error'
    })
end)

RegisterNetEvent(NEXA_DISPATCH_EVENTS.newCall, function(call)
    if call == nil then
        return
    end

    lib.notify({
        title = 'Notruf',
        description = ('Einsatz %s wurde erstellt.'):format(call.call_number or call.callNumber or 'unbekannt'),
        type = 'inform'
    })
end)

RegisterCommand('nexadispatch', function()
    if not NexaDispatchClient.enableOxContext then
        return
    end

    lib.registerContext({
        id = 'nexa_dispatch_menu',
        title = 'Dispatch',
        options = {
            {
                title = 'Aktive Einsaetze laden',
                onSelect = function()
                    lib.callback.await('nexa:dispatch:cb:listCalls', false, {
                        status = 'open'
                    })
                end
            }
        }
    })

    lib.showContext('nexa_dispatch_menu')
end, false)
