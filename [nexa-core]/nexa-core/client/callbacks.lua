NexaClient = NexaClient or {}
NexaClient.Callbacks = {
    handlers = {},
    pending = {}
}

local nextRequestId = 0

local function makeRequestId(name)
    nextRequestId = nextRequestId + 1
    return ('client:%s:%s'):format(GetGameTimer(), nextRequestId)
end

function NexaClient.Callbacks.Register(name, handler)
    if type(name) ~= 'string' or name == '' or type(handler) ~= 'function' then
        Nexa.Log('error', 'Client-Callback-Registrierung ungueltig.', {
            name = name
        })
        return false
    end

    NexaClient.Callbacks.handlers[name] = handler
    return true
end

function NexaClient.Callbacks.Trigger(name, payload, cb)
    if type(name) ~= 'string' or name == '' then
        if cb then
            cb(Nexa.Response.fail('INVALID_INPUT', 'Callback konnte nicht gesendet werden.'))
        end

        return false
    end

    local requestId = makeRequestId(name)

    if cb then
        NexaClient.Callbacks.pending[requestId] = cb

        SetTimeout(Nexa.Config.callbacks.timeoutMs, function()
            local pending = NexaClient.Callbacks.pending[requestId]

            if not pending then
                return
            end

            NexaClient.Callbacks.pending[requestId] = nil
            pending(Nexa.Response.fail('TIMEOUT', 'Callback-Zeitlimit erreicht.'))
        end)
    end

    TriggerServerEvent(Nexa.Constants.callbacks.clientRequest, requestId, name, payload)
    return true
end

RegisterNetEvent(Nexa.Constants.callbacks.clientResponse, function(requestId, response)
    local cb = NexaClient.Callbacks.pending[requestId]

    if not cb then
        return
    end

    NexaClient.Callbacks.pending[requestId] = nil
    cb(response)
end)

RegisterNetEvent(Nexa.Constants.callbacks.serverRequest, function(requestId, name, payload)
    local handler = NexaClient.Callbacks.handlers[name]

    if type(requestId) ~= 'string' or type(name) ~= 'string' then
        return
    end

    if not handler then
        TriggerServerEvent(Nexa.Constants.callbacks.serverResponse, requestId, Nexa.Response.fail('NOT_FOUND', 'Callback nicht registriert.'))
        return
    end

    local ok, response = pcall(handler, payload)

    if not ok then
        Nexa.Log('error', 'Client-Callback fehlgeschlagen.', {
            name = name,
            error = response
        })

        TriggerServerEvent(Nexa.Constants.callbacks.serverResponse, requestId, Nexa.Response.fail('INTERNAL_ERROR', 'Der Vorgang konnte nicht abgeschlossen werden.'))
        return
    end

    TriggerServerEvent(Nexa.Constants.callbacks.serverResponse, requestId, response)
end)

function NexaClient.Callbacks.GetSession(cb)
    return NexaClient.Callbacks.Trigger(NEXA_CONSTANTS.callbacks.getSession, nil, cb)
end

function NexaClient.Callbacks.GetCharacters(cb)
    return NexaClient.Callbacks.Trigger(NEXA_CONSTANTS.callbacks.getCharacters, nil, cb)
end
