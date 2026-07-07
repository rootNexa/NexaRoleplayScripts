RegisterNetEvent(NEXA_EVIDENCE_EVENTS.requestResult, function(response)
    if type(response) ~= 'table' then
        return
    end

    lib.notify({
        title = 'Evidence',
        description = response.message or 'Anfrage abgeschlossen.',
        type = response.success and 'success' or 'error'
    })
end)
