CreateThread(function()
    Wait(500)

    local response = NexaClient.Callbacks.GetSession()

    if response and response.success and response.data then
        NexaClient.Session.player = response.data.player
        NexaClient.Session.character = response.data.character
    end
end)

RegisterNetEvent('nexa:core:client:characterSelectFailed', function(payload)
    if lib and lib.notify then
        lib.notify({
            type = 'error',
            title = 'Nexa',
            description = payload and payload.message or 'Charakter konnte nicht geladen werden.'
        })
    end
end)
