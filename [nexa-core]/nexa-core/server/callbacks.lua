Nexa.Callbacks = {
    handlers = {},
    networkHandlers = {},
    pendingClient = {},
    lastCall = {},
    requestCounter = 0
}

local CALLBACK_NAME_PATTERN = '^nexa:[%w_%-]+:cb:[%w_%-:]+$'

local function makeResponse(data)
    return {
        ok = true,
        data = data
    }
end

local function makeError(code, message, details)
    return {
        ok = false,
        error = {
            code = code or 'INTERNAL_ERROR',
            message = message or 'Der Vorgang konnte nicht abgeschlossen werden.',
            details = details
        }
    }
end

local function publicError(code, message)
    return makeError(code, message)
end

local function isValidCallbackName(name)
    return type(name) == 'string' and name:match(CALLBACK_NAME_PATTERN) ~= nil
end

local function isCallable(value)
    if type(value) == 'function' then
        return true
    end

    if type(value) ~= 'table' and type(value) ~= 'userdata' then
        return false
    end

    local metatable = getmetatable(value)
    return type(metatable) == 'table' and type(metatable.__call) == 'function'
end

local function validatePayload(payload, validator)
    if validator == nil then
        return true, nil
    end

    if type(validator) ~= 'function' then
        return false, 'INVALID_VALIDATOR'
    end

    local ok, result, err = pcall(validator, payload)

    if not ok then
        return false, 'VALIDATOR_FAILED'
    end

    if result ~= true then
        return false, err or 'INVALID_PAYLOAD'
    end

    return true, nil
end

local function makeRequestId(prefix, source, name)
    Nexa.Callbacks.requestCounter = Nexa.Callbacks.requestCounter + 1
    return ('%s:%s:%s:%s:%s'):format(prefix, source or 0, GetGameTimer(), Nexa.Callbacks.requestCounter, name)
end

local function canCall(source, name, options)
    options = options or {}
    local cooldownMs = tonumber(options.rateLimitMs) or Nexa.Config.callbacks.defaultCooldownMs

    if cooldownMs <= 0 then
        return true
    end

    local key = ('%s:%s'):format(source, name)
    local now = GetGameTimer()
    local last = Nexa.Callbacks.lastCall[key] or 0

    if last > 0 and now - last < cooldownMs then
        return false
    end

    Nexa.Callbacks.lastCall[key] = now
    return true
end

local function normalizeHandlerResponse(ok, result, err)
    if not ok then
        return makeError('HANDLER_ERROR', 'Interner Callback-Handler fehlgeschlagen.', {
            error = tostring(result)
        })
    end

    if type(result) == 'table' and result.ok ~= nil then
        return result
    end

    if err ~= nil then
        return makeError(tostring(err), 'Der Vorgang konnte nicht abgeschlossen werden.')
    end

    return makeResponse(result)
end

local function sanitizeForClient(response)
    if type(response) ~= 'table' then
        return publicError('INTERNAL_ERROR', 'Der Vorgang konnte nicht abgeschlossen werden.')
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

function Nexa.Callbacks.Register(name, handler, options)
    if not isValidCallbackName(name) or not isCallable(handler) then
        Nexa.Logger.Error('callbacks.register', 'Interne Callback-Registrierung ungueltig.', {
            name = name
        })
        return false, 'INVALID_INPUT'
    end

    Nexa.Callbacks.handlers[name] = {
        handler = handler,
        options = options or {},
        registeredAt = os.time()
    }

    return true, nil
end

function Nexa.Callbacks.RegisterNetwork(name, handler, options)
    if not isValidCallbackName(name) or not isCallable(handler) then
        Nexa.Logger.Error('callbacks.network.register', 'Netzwerk-Callback-Registrierung ungueltig.', {
            name = name
        })
        return false, 'INVALID_INPUT'
    end

    Nexa.Callbacks.networkHandlers[name] = {
        handler = handler,
        options = options or {},
        registeredAt = os.time()
    }

    return true, nil
end

function Nexa.Callbacks.Unregister(name)
    if not isValidCallbackName(name) then
        return false, 'INVALID_INPUT'
    end

    Nexa.Callbacks.handlers[name] = nil
    Nexa.Callbacks.networkHandlers[name] = nil
    return true, nil
end

function Nexa.Callbacks.Has(name)
    return Nexa.Callbacks.handlers[name] ~= nil or Nexa.Callbacks.networkHandlers[name] ~= nil
end

function Nexa.Callbacks.Call(name, payload, context)
    local entry = Nexa.Callbacks.handlers[name]

    if not entry then
        return makeError('NOT_FOUND', 'Callback nicht registriert.')
    end

    local valid, validationErr = validatePayload(payload, entry.options.validate)

    if not valid then
        return makeError('INVALID_PAYLOAD', 'Payload ist ungueltig.', {
            reason = validationErr
        })
    end

    return normalizeHandlerResponse(pcall(entry.handler, payload, context or {}))
end

function Nexa.Callbacks.TriggerClient(source, name, payload, cb, options)
    source = tonumber(source)
    options = options or {}

    if not source or source <= 0 or not isValidCallbackName(name) then
        if cb then
            cb(publicError('INVALID_INPUT', 'Callback konnte nicht gesendet werden.'))
        end

        return false, 'INVALID_INPUT'
    end

    local requestId = makeRequestId('server', source, name)
    local timeoutMs = tonumber(options.timeoutMs) or Nexa.Config.callbacks.timeoutMs

    if cb then
        Nexa.Callbacks.pendingClient[requestId] = {
            source = source,
            name = name,
            cb = cb,
            createdAt = os.time()
        }

        SetTimeout(timeoutMs, function()
            local pending = Nexa.Callbacks.pendingClient[requestId]

            if not pending then
                return
            end

            Nexa.Callbacks.pendingClient[requestId] = nil
            pending.cb(publicError('TIMEOUT', 'Callback-Zeitlimit erreicht.'), source)
        end)
    end

    TriggerClientEvent(Nexa.Constants.callbacks.serverRequest, source, requestId, name, payload)
    return true, requestId
end

function Nexa.Callbacks.TriggerClientAwait(source, name, payload, options)
    if not promise or not Citizen or not Citizen.Await then
        return publicError('AWAIT_UNAVAILABLE', 'Await ist in diesem Kontext nicht verfuegbar.')
    end

    local pending = promise.new()
    local sent = Nexa.Callbacks.TriggerClient(source, name, payload, function(response)
        pending:resolve(response)
    end, options)

    if not sent then
        return publicError('INVALID_INPUT', 'Callback konnte nicht gesendet werden.')
    end

    return Citizen.Await(pending)
end

function Nexa.Callbacks.CallAwait(name, payload, context)
    return Nexa.Callbacks.Call(name, payload, context)
end

function Nexa.Callbacks.Trigger(source, name, payload, cb)
    return Nexa.Callbacks.TriggerClient(source, name, payload, cb)
end

RegisterNetEvent(Nexa.Constants.callbacks.clientRequest, function(requestId, name, payload)
    local requestSource = source

    if type(requestSource) ~= 'number' or requestSource <= 0 or type(requestId) ~= 'string' or not isValidCallbackName(name) then
        return
    end

    local ready, readyErr = Nexa.Lifecycle.RequireReady(('callback:%s'):format(name))

    if not ready then
        TriggerClientEvent(Nexa.Constants.callbacks.clientResponse, requestSource, requestId, publicError(readyErr, 'Core ist noch nicht bereit.'))
        return
    end

    local entry = Nexa.Callbacks.networkHandlers[name]

    if not entry then
        TriggerClientEvent(Nexa.Constants.callbacks.clientResponse, requestSource, requestId, publicError('NOT_FOUND', 'Callback nicht registriert.'))
        return
    end

    if not canCall(requestSource, name, entry.options) then
        TriggerClientEvent(Nexa.Constants.callbacks.clientResponse, requestSource, requestId, publicError('RATE_LIMITED', 'Bitte warte kurz.'))
        return
    end

    local valid, validationErr = validatePayload(payload, entry.options.validate)

    if not valid then
        TriggerClientEvent(Nexa.Constants.callbacks.clientResponse, requestSource, requestId, publicError('INVALID_PAYLOAD', 'Payload ist ungueltig.'))
        Nexa.Logger.Warn('callbacks.network.payload', 'Ungueltige Callback-Payload blockiert.', {
            name = name,
            source = requestSource,
            reason = validationErr
        })
        return
    end

    local context = {
        source = requestSource,
        requestId = requestId,
        network = true
    }

    local response = normalizeHandlerResponse(pcall(entry.handler, requestSource, payload, context))

    if response.ok ~= true then
        Nexa.Logger.Warn('callbacks.network.error', 'Netzwerk-Callback lieferte Fehlerantwort.', {
            name = name,
            source = requestSource,
            code = response.error and response.error.code or 'UNKNOWN'
        })
    end

    TriggerClientEvent(Nexa.Constants.callbacks.clientResponse, requestSource, requestId, sanitizeForClient(response))
end)

RegisterNetEvent(Nexa.Constants.callbacks.serverResponse, function(requestId, response)
    local responseSource = source

    if type(requestId) ~= 'string' then
        return
    end

    local pending = Nexa.Callbacks.pendingClient[requestId]

    if not pending then
        Nexa.Logger.Warn('callbacks.client_response.unknown', 'Unbekannte Callback-Response ignoriert.', {
            requestId = requestId,
            source = responseSource
        })
        return
    end

    if pending.source ~= responseSource then
        Nexa.Logger.Security('callbacks.client_response.source', 'Callback-Response mit falscher Source blockiert.', {
            requestId = requestId,
            expectedSource = pending.source,
            source = responseSource
        })
        return
    end

    Nexa.Callbacks.pendingClient[requestId] = nil
    pending.cb(sanitizeForClient(response), responseSource)
end)

AddEventHandler('playerDropped', function()
    local droppedSource = source

    for requestId, pending in pairs(Nexa.Callbacks.pendingClient) do
        if pending.source == droppedSource then
            Nexa.Callbacks.pendingClient[requestId] = nil
            pending.cb(publicError('DISCONNECTED', 'Spieler nicht mehr verbunden.'), droppedSource)
        end
    end
end)

Nexa.Callbacks.RegisterNetwork(Nexa.Constants.callbacks.getSession, function(source)
    local player = Nexa.Players.GetPublic(source)
    local character = Nexa.Characters.GetActive(source)

    if not player then
        return publicError('NOT_FOUND', 'Spieler nicht geladen.')
    end

    return makeResponse({
        player = player,
        character = character
    })
end)

Nexa.Callbacks.RegisterNetwork(Nexa.Constants.callbacks.getCharacters, function(source)
    local characters, err = Nexa.Characters.List(source)

    if err then
        return publicError(err, 'Charaktere konnten nicht geladen werden.')
    end

    return makeResponse(characters)
end)
