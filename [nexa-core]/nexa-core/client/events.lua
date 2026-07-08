NexaClient = NexaClient or {}
NexaClient.Session = {
    player = nil,
    character = nil
}
NexaClient.Events = NexaClient.Events or {}

function NexaClient.Events.RegisterNet(name, handler)
    if type(name) ~= 'string' or type(handler) ~= 'function' then
        Nexa.Log('error', 'Clientevent-Registrierung ungueltig.', {
            event = name
        })
        return false
    end

    RegisterNetEvent(name, function(...)
        local ok, err = pcall(handler, ...)

        if not ok then
            Nexa.Log('error', 'Clientevent fehlgeschlagen.', {
                event = name,
                error = err
            })
        end
    end)

    return true
end

function NexaClient.Events.EmitServer(name, payload)
    if type(name) ~= 'string' then
        return false
    end

    TriggerServerEvent(name, payload)
    return true
end

NexaClient.Events.RegisterNet(NEXA_CONSTANTS.events.playerLoaded, function(player)
    NexaClient.Session.player = player
end)

NexaClient.Events.RegisterNet(NEXA_CONSTANTS.events.characterSelected, function(character)
    NexaClient.Session.character = character
end)

NexaClient.Events.RegisterNet(NEXA_CONSTANTS.events.characterUnloaded, function()
    NexaClient.Session.character = nil
end)
