local function notify(response)
    if response == nil then
        return
    end

    lib.notify({
        title = 'Dokumente',
        description = response.message or 'Vorgang abgeschlossen.',
        type = response.success and 'success' or 'error'
    })
end

RegisterNetEvent(NEXA_DOCUMENTS_EVENTS.requestResult, notify)

RegisterNetEvent(NEXA_DOCUMENTS_EVENTS.requestOpenMenu, function()
    lib.registerContext({
        id = NexaDocumentsClient.contextId,
        title = 'Dokumente',
        options = {
            {
                title = 'Dokumenttypen laden',
                icon = 'file-text',
                onSelect = function()
                    local response = lib.callback.await('nexa:documents:cb:listTypes', false)
                    notify(response)
                end
            },
            {
                title = 'Dokument pruefen',
                icon = 'shield-check',
                onSelect = function()
                    local input = lib.inputDialog('Dokument pruefen', {
                        { type = 'input', label = 'Dokumentnummer', required = true }
                    })

                    if input == nil then
                        return
                    end

                    local response = lib.callback.await('nexa:documents:cb:validateDocument', false, {
                        documentNumber = input[1]
                    })

                    notify(response)
                end
            }
        }
    })

    lib.showContext(NexaDocumentsClient.contextId)
end)
