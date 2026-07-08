CreateThread(function()
    Wait(500)

    NexaClient.Callbacks.GetSession(function(response)
        if response and response.success and response.data then
            NexaClient.Session.player = response.data.player
            NexaClient.Session.character = response.data.character
        end
    end)
end)

RegisterNetEvent('nexa:core:client:characterSelectFailed', function(payload)
    Nexa.Log('error', payload and payload.message or 'Charakter konnte nicht geladen werden.', {
        code = payload and payload.code or nil
    })
end)
