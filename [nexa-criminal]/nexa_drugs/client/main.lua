RegisterNetEvent(NEXA_DRUGS_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    lib.notify({
        title = 'Drogen',
        description = response.message,
        type = response.success and 'success' or 'error'
    })
end)

RegisterCommand('nexadrugs', function()
    if not NexaDrugsClient.enableOxContext then
        return
    end

    lib.registerContext({
        id = 'nexa_drugs_menu',
        title = 'Drogen',
        options = {
            {
                title = 'Pflanzen',
                onSelect = function()
                    local input = lib.inputDialog('Pflanzen', {
                        { type = 'input', label = 'Pflanzen-ID', required = true }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(NEXA_DRUGS_EVENTS.requestPlant, {
                        cropId = input[1]
                    })
                end
            },
            {
                title = 'Ernten',
                onSelect = function()
                    local input = lib.inputDialog('Ernten', {
                        { type = 'number', label = 'Batch-ID', required = true, min = 1 }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(NEXA_DRUGS_EVENTS.requestHarvest, {
                        batchId = input[1]
                    })
                end
            },
            {
                title = 'Verarbeiten',
                onSelect = function()
                    local input = lib.inputDialog('Verarbeiten', {
                        { type = 'input', label = 'Rezept-ID', required = true },
                        { type = 'number', label = 'Menge', required = true, min = 1 }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(NEXA_DRUGS_EVENTS.requestProcess, {
                        recipeId = input[1],
                        amount = input[2]
                    })
                end
            },
            {
                title = 'Verkaufen',
                onSelect = function()
                    local input = lib.inputDialog('Verkaufen', {
                        { type = 'input', label = 'Kontakt-ID', required = true },
                        { type = 'number', label = 'Menge', required = true, min = 1 },
                        { type = 'input', label = 'Kontonummer', required = false }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(NEXA_DRUGS_EVENTS.requestSell, {
                        buyerId = input[1],
                        amount = input[2],
                        accountNumber = input[3]
                    })
                end
            }
        }
    })

    lib.showContext('nexa_drugs_menu')
end, false)
