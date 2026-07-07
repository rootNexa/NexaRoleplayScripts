RegisterNetEvent(NEXA_BLACKMARKET_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    lib.notify({
        title = 'Schwarzmarkt',
        description = response.message,
        type = response.success and 'success' or 'error'
    })
end)

RegisterCommand('nexablackmarket', function()
    if not NexaBlackmarketClient.enableOxContext then
        return
    end

    lib.registerContext({
        id = 'nexa_blackmarket_menu',
        title = 'Schwarzmarkt',
        options = {
            {
                title = 'Katalog laden',
                onSelect = function()
                    lib.callback.await('nexa:blackmarket:cb:getCatalog', false)
                end
            },
            {
                title = 'Kauf anfragen',
                onSelect = function()
                    local input = lib.inputDialog('Schwarzmarkt-Kauf', {
                        { type = 'input', label = 'Haendler-ID', required = true },
                        { type = 'input', label = 'Katalog-ID', required = true },
                        { type = 'number', label = 'Menge', required = true, min = 1 },
                        { type = 'input', label = 'Kontonummer', required = false }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(NEXA_BLACKMARKET_EVENTS.requestBuy, {
                        dealerId = input[1],
                        catalogId = input[2],
                        amount = input[3],
                        accountNumber = input[4]
                    })
                end
            },
            {
                title = 'Verkauf anfragen',
                onSelect = function()
                    local input = lib.inputDialog('Schwarzmarkt-Verkauf', {
                        { type = 'input', label = 'Haendler-ID', required = true },
                        { type = 'input', label = 'Katalog-ID', required = true },
                        { type = 'number', label = 'Menge', required = true, min = 1 },
                        { type = 'input', label = 'Kontonummer', required = false }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(NEXA_BLACKMARKET_EVENTS.requestSell, {
                        dealerId = input[1],
                        catalogId = input[2],
                        amount = input[3],
                        accountNumber = input[4]
                    })
                end
            }
        }
    })

    lib.showContext('nexa_blackmarket_menu')
end, false)
