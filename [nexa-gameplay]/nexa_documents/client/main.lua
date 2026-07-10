local function awaitServerCallback(name, payload)
    local waiter = promise.new()
    local request = exports.nexa_api:TriggerServerCallback(name, payload or {}, function(response)
        waiter:resolve(response)
    end, 5000)

    if type(request) == 'table' and request.ok == false then
        return request
    end

    return Citizen.Await(waiter)
end

local function notify(response)
    if response == nil then
        return
    end

    exports.nexa_ui:notify({
        title = 'Dokumente',
        description = response.message or 'Vorgang abgeschlossen.',
        type = response.success and 'success' or 'error'
    })
end

RegisterNetEvent(NEXA_DOCUMENTS_EVENTS.requestResult, notify)

RegisterNetEvent(NEXA_DOCUMENTS_EVENTS.requestOpenMenu, function()
    exports.nexa_ui:registerContext({
        id = NexaDocumentsClient.contextId,
        title = 'Dokumente',
        options = {
            {
                title = 'Dokumenttypen laden',
                icon = 'file-text',
                onSelect = function()
                    local response = awaitServerCallback('nexa:documents:cb:listTypes', {})
                    notify(response)
                end
            },
            {
                title = 'Dokument pruefen',
                icon = 'shield-check',
                onSelect = function()
                    local input = exports.nexa_ui:inputDialog('Dokument pruefen', {
                        { type = 'input', label = 'Dokumentnummer', required = true }
                    })

                    if input == nil then
                        return
                    end

                    local response = awaitServerCallback('nexa:documents:cb:validateDocument', {
                        documentNumber = input[1]
                    })

                    notify(response)
                end
            }
        }
    })

    exports.nexa_ui:showContext(NexaDocumentsClient.contextId)
end)
