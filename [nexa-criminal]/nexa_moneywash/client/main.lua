RegisterNetEvent(NEXA_MONEYWASH_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    lib.notify({
        title = 'Geldwaesche',
        description = response.message,
        type = response.success and 'success' or 'error'
    })
end)

RegisterCommand('nexamoneywash', function()
    if not NexaMoneywashClient.enableOxContext then
        return
    end

    lib.registerContext({
        id = 'nexa_moneywash_menu',
        title = 'Geldwaesche',
        options = {
            {
                title = 'Waschen',
                onSelect = function()
                    local input = lib.inputDialog('Geldwaesche', {
                        { type = 'input', label = 'Station-ID', required = true },
                        { type = 'number', label = 'Menge', required = true, min = 1 },
                        { type = 'input', label = 'Kontonummer', required = false }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(NEXA_MONEYWASH_EVENTS.requestWash, {
                        stationId = input[1],
                        amount = input[2],
                        accountNumber = input[3]
                    })
                end
            }
        }
    })

    lib.showContext('nexa_moneywash_menu')
end, false)
