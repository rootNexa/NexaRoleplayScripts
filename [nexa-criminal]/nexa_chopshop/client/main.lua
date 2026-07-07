RegisterNetEvent(NEXA_CHOPSHOP_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    lib.notify({
        title = 'Chopshop',
        description = response.message,
        type = response.success and 'success' or 'error'
    })
end)

RegisterCommand('nexachopshop', function()
    if not NexaChopshopClient.enableOxContext then
        return
    end

    lib.registerContext({
        id = 'nexa_chopshop_menu',
        title = 'Chopshop',
        options = {
            {
                title = 'Fahrzeug zerlegen',
                onSelect = function()
                    local input = lib.inputDialog('Fahrzeug zerlegen', {
                        { type = 'input', label = 'Yard-ID', required = true },
                        { type = 'number', label = 'Vehicle-ID', required = true, min = 1 }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(NEXA_CHOPSHOP_EVENTS.requestDismantle, {
                        yardId = input[1],
                        vehicleId = input[2]
                    })
                end
            },
            {
                title = 'Teile verkaufen',
                onSelect = function()
                    local input = lib.inputDialog('Teile verkaufen', {
                        { type = 'input', label = 'Kontakt-ID', required = true },
                        { type = 'input', label = 'Item', required = true },
                        { type = 'number', label = 'Menge', required = true, min = 1 },
                        { type = 'input', label = 'Kontonummer', required = false }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(NEXA_CHOPSHOP_EVENTS.requestSell, {
                        buyerId = input[1],
                        itemName = input[2],
                        amount = input[3],
                        accountNumber = input[4]
                    })
                end
            }
        }
    })

    lib.showContext('nexa_chopshop_menu')
end, false)
