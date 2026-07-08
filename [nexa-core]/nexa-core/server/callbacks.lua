Nexa.Callbacks = {
    lastCall = {}
}

local function canCall(source, name)
    local key = ('%s:%s'):format(source, name)
    local now = GetGameTimer()
    local last = Nexa.Callbacks.lastCall[key] or 0

    if last > 0 and now - last < Nexa.Config.callbacks.defaultCooldownMs then
        return false
    end

    Nexa.Callbacks.lastCall[key] = now
    return true
end

function Nexa.Callbacks.Register(name, handler)
    lib.callback.register(name, function(source, ...)
        if not canCall(source, name) then
            return Nexa.Response(false, 'RATE_LIMITED', 'Bitte warte kurz.', nil, nil)
        end

        local ok, response = pcall(handler, source, ...)

        if not ok then
            Nexa.Log('error', 'Callback fehlgeschlagen.', {
                name = name,
                source = source,
                error = response
            })
            return Nexa.Response(false, 'INTERNAL_ERROR', 'Der Vorgang konnte nicht abgeschlossen werden.', nil, nil)
        end

        return response
    end)
end

Nexa.Callbacks.Register(Nexa.Constants.callbacks.getSession, function(source)
    local player = Nexa.Players.GetPublic(source)
    local character = Nexa.Characters.GetActive(source)

    if not player then
        return Nexa.Response(false, 'NOT_FOUND', 'Spieler nicht geladen.', nil, nil)
    end

    return Nexa.Response(true, 'OK', 'Session geladen.', {
        player = player,
        character = character
    }, nil)
end)

Nexa.Callbacks.Register(Nexa.Constants.callbacks.getCharacters, function(source)
    local characters, err = Nexa.Characters.List(source)

    if err then
        return Nexa.Response(false, err, 'Charaktere konnten nicht geladen werden.', nil, nil)
    end

    return Nexa.Response(true, 'OK', 'Charaktere geladen.', characters, {
        count = #characters
    })
end)
