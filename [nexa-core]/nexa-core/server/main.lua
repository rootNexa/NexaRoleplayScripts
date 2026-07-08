CreateThread(function()
    Wait(0)
    Nexa.Bootstrap.Run()

    for _, playerSource in ipairs(GetPlayers()) do
        Nexa.Players.Register(tonumber(playerSource))
    end
end)

AddEventHandler('playerJoining', function()
    local source = source

    CreateThread(function()
        local player, err = Nexa.Players.Register(source)

        if not player then
            Nexa.Log('error', 'Session konnte nicht initialisiert werden.', {
                source = source,
                error = err
            })
        end
    end)
end)

RegisterCommand('nexa_core_status', function(source)
    if source ~= 0 and not Nexa.Permissions.Has(source, 'admin.core.status') then
        return
    end

    local playerCount = 0

    for _ in pairs(Nexa.Players.bySource) do
        playerCount = playerCount + 1
    end

    Nexa.Log('info', 'Core Status', {
        started = Nexa.Bootstrap.started,
        players = playerCount
    })
end, true)
