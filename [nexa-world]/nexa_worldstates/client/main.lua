RegisterNetEvent(NEXA_WORLDSTATES_EVENTS.requestResult, function(response)
    if not NexaWorldStatesClient.enableNotifications or type(response) ~= 'table' then
        return
    end

    local ok = response.ok == true or response.success == true
    local message = response.message

    if not message and type(response.error) == 'table' then
        message = response.error.message
    end

    print(('[nexa_worldstates] %s %s'):format(ok and 'OK' or 'ERROR', message or 'Anfrage abgeschlossen.'))
end)
