Nexa.Callbacks = {
    handlers = {},
    pending = {},
    lastCall = {}
}

local nextRequestId = 0

local function makeRequestId(source, name)
    nextRequestId = nextRequestId + 1
    return ('%s:%s:%s'):format(source, GetGameTimer(), nextRequestId)
end

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
    if type(name) ~= 'string' or name == '' or type(handler) ~= 'function' then
        Nexa.Log('error', 'Callback-Registrierung ungueltig.', {
            name = name
        })
        return false
    end

    Nexa.Callbacks.handlers[name] = handler
    return true
end

function Nexa.Callbacks.Trigger(source, name, payload, cb)
    source = tonumber(source)

    if not source or source <= 0 or type(name) ~= 'string' then
        if cb then
            cb(Nexa.Response.fail('INVALID_INPUT', 'Callback konnte nicht gesendet werden.'))
        end

        return false
    end

    local requestId = makeRequestId(source, name)

    if cb then
        Nexa.Callbacks.pending[requestId] = {
            source = source,
            cb = cb
        }

        SetTimeout(Nexa.Config.callbacks.timeoutMs, function()
            local pending = Nexa.Callbacks.pending[requestId]

            if not pending then
                return
            end

            Nexa.Callbacks.pending[requestId] = nil
            pending.cb(Nexa.Response.fail('TIMEOUT', 'Callback-Zeitlimit erreicht.'))
        end)
    end

    TriggerClientEvent(Nexa.Constants.callbacks.serverRequest, source, requestId, name, payload)
    return true
end

RegisterNetEvent(Nexa.Constants.callbacks.clientRequest, function(requestId, name, payload)
    local source = source

    if type(source) ~= 'number' or source <= 0 or type(requestId) ~= 'string' or type(name) ~= 'string' then
        return
    end

    local ready, readyErr = Nexa.Lifecycle.RequireReady(('callback:%s'):format(name))

    if not ready then
        TriggerClientEvent(Nexa.Constants.callbacks.clientResponse, source, requestId, Nexa.Response.fail(readyErr, 'Core ist noch nicht bereit.'))
        return
    end

    local handler = Nexa.Callbacks.handlers[name]

    if not handler then
        TriggerClientEvent(Nexa.Constants.callbacks.clientResponse, source, requestId, Nexa.Response.fail('NOT_FOUND', 'Callback nicht registriert.'))
        return
    end

    if not canCall(source, name) then
        TriggerClientEvent(Nexa.Constants.callbacks.clientResponse, source, requestId, Nexa.Response.fail('RATE_LIMITED', 'Bitte warte kurz.'))
        return
    end

    local ok, response = pcall(handler, source, payload)

    if not ok then
        Nexa.Log('error', 'Callback fehlgeschlagen.', {
            name = name,
            source = source,
            error = response
        })

        TriggerClientEvent(Nexa.Constants.callbacks.clientResponse, source, requestId, Nexa.Response.fail('INTERNAL_ERROR', 'Der Vorgang konnte nicht abgeschlossen werden.'))
        return
    end

    TriggerClientEvent(Nexa.Constants.callbacks.clientResponse, source, requestId, response)
end)

RegisterNetEvent(Nexa.Constants.callbacks.serverResponse, function(requestId, response)
    local source = source
    local pending = Nexa.Callbacks.pending[requestId]

    if not pending or pending.source ~= source then
        return
    end

    Nexa.Callbacks.pending[requestId] = nil
    pending.cb(response, source)
end)

Nexa.Callbacks.Register(Nexa.Constants.callbacks.getSession, function(source)
    local player = Nexa.Players.GetPublic(source)
    local character = Nexa.Characters.GetActive(source)

    if not player then
        return Nexa.Response.fail('NOT_FOUND', 'Spieler nicht geladen.')
    end

    return Nexa.Response.ok({
        player = player,
        character = character
    }, nil, 'Session geladen.')
end)

Nexa.Callbacks.Register(Nexa.Constants.callbacks.getCharacters, function(source)
    local characters, err = Nexa.Characters.List(source)

    if err then
        return Nexa.Response.fail(err, 'Charaktere konnten nicht geladen werden.')
    end

    return Nexa.Response.ok(characters, {
        count = #characters
    }, 'Charaktere geladen.')
end)
