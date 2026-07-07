local function notify(response)
    if response == nil then
        return
    end

    lib.notify({
        title = 'Lizenzen',
        description = response.message or 'Vorgang abgeschlossen.',
        type = response.success and 'success' or 'error'
    })
end

RegisterNetEvent(NEXA_LICENSES_EVENTS.requestResult, notify)

RegisterNetEvent(NEXA_LICENSES_EVENTS.requestOpenMenu, function()
    lib.registerContext({
        id = NexaLicensesClient.contextId,
        title = 'Lizenzen',
        options = {
            {
                title = 'Lizenztypen laden',
                icon = 'badge-check',
                onSelect = function()
                    local response = lib.callback.await('nexa:licenses:cb:listTypes', false)
                    notify(response)
                end
            },
            {
                title = 'Lizenz pruefen',
                icon = 'shield-check',
                onSelect = function()
                    local input = lib.inputDialog('Lizenz pruefen', {
                        { type = 'number', label = 'Charakter-ID', required = true },
                        { type = 'input', label = 'Lizenztyp', required = true }
                    })

                    if input == nil then
                        return
                    end

                    local response = lib.callback.await('nexa:licenses:cb:validateLicense', false, {
                        characterId = input[1],
                        licenseType = input[2]
                    })

                    notify(response)
                end
            }
        }
    })

    lib.showContext(NexaLicensesClient.contextId)
end)
