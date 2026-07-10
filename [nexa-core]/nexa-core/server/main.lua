local startRequested = false

local function requestCoreStart()
    if startRequested then
        return
    end

    startRequested = true

    CreateThread(function()
        Wait(0)
        Nexa.Bootstrap.Start()
    end)
end

Nexa.Lifecycle.RegisterLifecycleHook(Nexa.Constants.lifecycle.stages.starting, function()
    for _, playerSource in ipairs(GetPlayers()) do
        Nexa.Players.Register(tonumber(playerSource))
    end
end)

Nexa.Lifecycle.RegisterLifecycleHook(Nexa.Constants.lifecycle.stages.stopping, function()
    for playerSource in pairs(Nexa.Players.bySource) do
        local ok, err = pcall(Nexa.Players.Drop, playerSource, 'core_stopping')

        if not ok then
            Nexa.Log('error', 'Session konnte beim Core-Stop nicht sauber entladen werden.', {
                source = playerSource,
                error = err
            })
        end
    end

    Nexa.Players.bySource = {}
    Nexa.Players.byIdentifier = {}

    if Nexa.Characters and Nexa.Characters.activeBySource then
        Nexa.Characters.activeBySource = {}
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= Nexa.Constants.resourceName then
        return
    end

    requestCoreStart()
end)

CreateThread(function()
    Wait(0)

    if Nexa.Lifecycle.GetState() == Nexa.Constants.lifecycle.states.created then
        requestCoreStart()
    end
end)

AddEventHandler('playerJoining', function()
    local source = source

    CreateThread(function()
        local ready = Nexa.Lifecycle.RequireReady('playerJoining')

        if not ready then
            return
        end

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
    if source ~= 0 and not Nexa.Permissions.Has(source, 'nexa.admin.core.status') then
        return
    end

    local playerCount = 0

    for _ in pairs(Nexa.Players.bySource) do
        playerCount = playerCount + 1
    end

    Nexa.Log('info', 'Core Status', {
        started = Nexa.Bootstrap.started,
        state = Nexa.Lifecycle.GetState(),
        ready = Nexa.Lifecycle.IsReady(),
        startTimestamp = Nexa.Lifecycle.GetStartTimestamp(),
        failureReason = Nexa.Lifecycle.GetFailureReason(),
        players = playerCount
    })
end, true)
