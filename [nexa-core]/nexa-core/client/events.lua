NexaClient = NexaClient or {}
NexaClient.Session = {
    player = nil,
    character = nil
}

RegisterNetEvent(NEXA_CONSTANTS.events.playerLoaded, function(player)
    NexaClient.Session.player = player
end)

RegisterNetEvent(NEXA_CONSTANTS.events.characterSelected, function(character)
    NexaClient.Session.character = character
end)

RegisterNetEvent(NEXA_CONSTANTS.events.characterUnloaded, function()
    NexaClient.Session.character = nil
end)
