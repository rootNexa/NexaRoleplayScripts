RegisterNetEvent(NEXA_WORLDSTATES_EVENTS.requestResult, function(response)
    if not NexaWorldStatesClient.enableNotifications or type(response) ~= 'table' then
        return
    end

    lib.notify({
        title = 'World States',
        description = response.message or 'Anfrage abgeschlossen.',
        type = response.success and 'success' or 'error'
    })
end)
