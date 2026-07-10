NexaClient = NexaClient or {}
NexaClient.Callbacks = {
    handlers = {},
    pending = {},
    requestCounter = 0
}

local CALLBACK_NAME_PATTERN = '^nexa:[%w_%-]+:cb:[%w_%-:]+$'

local function isValidCallbackName(name)
    return type(name) == 'string' and name:match(CALLBACK_NAME_PATTERN) ~= nil
end

local function makeResponse(data)
    return {
        ok = true,
        data = data
    }
end

local function makeError(code, message)
    return {
        ok = false,
        error = {
            code = code or 'INTERNAL_ERROR',
            message = message or 'Der Vorgang konnte nicht abgeschlossen werden.'
        }
    }
end

local function makeRequestId(name)
    NexaClient.Callbacks.requestCounter = NexaClient.Callbacks.requestCounter + 1
    return ('client:%s:%s:%s'):format(GetGameTimer(), NexaClient.Callbacks.requestCounter, name)
end

local function sanitizeForServer(response)
    if type(response) ~= 'table' then
        return makeError('INTERNAL_ERROR', 'Der Vorgang konnte nicht abgeschlossen werden.')
    end

    if response.ok == true then
        return {
            ok = true,
            data = response.data
        }
    end

    local errorData = type(response.error) == 'table' and response.error or {}

    return {
        ok = false,
        error = {
            code = errorData.code or 'INTERNAL_ERROR',
            message = errorData.message or 'Der Vorgang konnte nicht abgeschlossen werden.'
        }
    }
end

function NexaClient.Callbacks.Register(name, handler)
    if not isValidCallbackName(name) or type(handler) ~= 'function' then
        Nexa.Log('error', 'Client-Callback-Registrierung ungueltig.', {
            name = name
        })
        return false, 'INVALID_INPUT'
    end

    NexaClient.Callbacks.handlers[name] = handler
    return true, nil
end

function NexaClient.Callbacks.Unregister(name)
    if not isValidCallbackName(name) then
        return false, 'INVALID_INPUT'
    end

    NexaClient.Callbacks.handlers[name] = nil
    return true, nil
end

function NexaClient.Callbacks.Has(name)
    return NexaClient.Callbacks.handlers[name] ~= nil
end

function NexaClient.Callbacks.Trigger(name, payload, cb, timeoutMs)
    if not isValidCallbackName(name) then
        if cb then
            cb(makeError('INVALID_INPUT', 'Callback konnte nicht gesendet werden.'))
        end

        return false, 'INVALID_INPUT'
    end

    local requestId = makeRequestId(name)

    if cb then
        NexaClient.Callbacks.pending[requestId] = cb

        SetTimeout(tonumber(timeoutMs) or Nexa.Config.callbacks.timeoutMs, function()
            local pending = NexaClient.Callbacks.pending[requestId]

            if not pending then
                return
            end

            NexaClient.Callbacks.pending[requestId] = nil
            pending(makeError('TIMEOUT', 'Callback-Zeitlimit erreicht.'))
        end)
    end

    TriggerServerEvent(Nexa.Constants.callbacks.clientRequest, requestId, name, payload)
    return true, requestId
end

function NexaClient.Callbacks.TriggerAwait(name, payload, timeoutMs)
    if not promise or not Citizen or not Citizen.Await then
        return makeError('AWAIT_UNAVAILABLE', 'Await ist in diesem Kontext nicht verfuegbar.')
    end

    local pending = promise.new()
    local sent = NexaClient.Callbacks.Trigger(name, payload, function(response)
        pending:resolve(response)
    end, timeoutMs)

    if not sent then
        return makeError('INVALID_INPUT', 'Callback konnte nicht gesendet werden.')
    end

    return Citizen.Await(pending)
end

RegisterNetEvent(Nexa.Constants.callbacks.clientResponse, function(requestId, response)
    local cb = NexaClient.Callbacks.pending[requestId]

    if not cb then
        Nexa.Log('warn', 'Unbekannte Callback-Response ignoriert.', {
            requestId = requestId
        })
        return
    end

    NexaClient.Callbacks.pending[requestId] = nil
    cb(response)
end)

RegisterNetEvent(Nexa.Constants.callbacks.serverRequest, function(requestId, name, payload)
    if type(requestId) ~= 'string' or not isValidCallbackName(name) then
        return
    end

    local handler = NexaClient.Callbacks.handlers[name]

    if not handler then
        TriggerServerEvent(Nexa.Constants.callbacks.serverResponse, requestId, makeError('NOT_FOUND', 'Callback nicht registriert.'))
        return
    end

    local ok, response = pcall(handler, payload, {
        requestId = requestId,
        network = true
    })

    if not ok then
        Nexa.Log('error', 'Client-Callback fehlgeschlagen.', {
            name = name,
            error = response
        })

        TriggerServerEvent(Nexa.Constants.callbacks.serverResponse, requestId, makeError('INTERNAL_ERROR', 'Der Vorgang konnte nicht abgeschlossen werden.'))
        return
    end

    if type(response) ~= 'table' or response.ok == nil then
        response = makeResponse(response)
    end

    TriggerServerEvent(Nexa.Constants.callbacks.serverResponse, requestId, sanitizeForServer(response))
end)

function NexaClient.Callbacks.GetSession(cb)
    return NexaClient.Callbacks.Trigger(NEXA_CONSTANTS.callbacks.getSession, nil, cb)
end

function NexaClient.Callbacks.GetCharacters(cb)
    return NexaClient.Callbacks.Trigger(NEXA_CONSTANTS.callbacks.getCharacters, nil, cb)
end
