RegisterNetEvent(NEXA_BUSINESS_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    lib.notify({
        title = 'Firma',
        description = response.message,
        type = response.success and 'success' or 'error'
    })
end)

RegisterCommand('nexabusiness', function()
    if not NexaBusinessClient.enableOxContext then
        return
    end

    lib.registerContext({
        id = 'nexa_business_menu',
        title = 'Firma',
        options = {
            {
                title = 'Firmen laden',
                onSelect = function()
                    lib.callback.await('nexa:business:cb:listBusinesses', false)
                end
            }
        }
    })

    lib.showContext('nexa_business_menu')
end, false)
