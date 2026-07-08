NexaLib.ServerCallbacks = {
    handlers = {},
    pending = {}
}

local nextRequestId = 0

local function makeRequestId(source, name)
    nextRequestId = nextRequestId + 1
    return ('server:%s:%s:%s'):format(source, GetGameTimer(), nextRequestId)
end

function NexaLib.ServerCallbacks.Register(name, handler)
    if type(name) ~= 'string' or name == '' or type(handler) ~= 'function' then
        return false
    end

    NexaLib.ServerCallbacks.handlers[name] = handler
    return true
end

function NexaLib.ServerCallbacks.Trigger(source, name, payload, cb, timeoutMs)
    source = tonumber(source)

    if not source or source <= 0 or type(name) ~= 'string' then
        if cb then
            cb(NexaLib.Response.fail('INVALID_INPUT', 'Callback request is invalid.'))
        end

        return false
    end

    local requestId = makeRequestId(source, name)

    if cb then
        NexaLib.ServerCallbacks.pending[requestId] = {
            source = source,
            cb = cb
        }

        SetTimeout(timeoutMs or NexaLib.Defaults.callbackTimeoutMs, function()
            local pending = NexaLib.ServerCallbacks.pending[requestId]

            if not pending then
                return
            end

            NexaLib.ServerCallbacks.pending[requestId] = nil
            pending.cb(NexaLib.Response.fail('TIMEOUT', 'Callback timed out.'))
        end)
    end

    TriggerClientEvent(NexaLib.CallbackEvents.serverRequest, source, requestId, name, payload)
    return true
end

RegisterNetEvent(NexaLib.CallbackEvents.clientRequest, function(requestId, name, payload)
    local source = source

    if type(source) ~= 'number' or source <= 0 or type(requestId) ~= 'string' or type(name) ~= 'string' then
        return
    end

    local handler = NexaLib.ServerCallbacks.handlers[name]

    if not handler then
        TriggerClientEvent(NexaLib.CallbackEvents.clientResponse, source, requestId, NexaLib.Response.fail('NOT_FOUND', 'Callback is not registered.'))
        return
    end

    local ok, result = pcall(handler, source, payload)

    if not ok then
        NexaLib.Logger.error('nexa-lib', 'Server callback failed.', {
            name = name,
            source = source,
            error = result
        })
        TriggerClientEvent(NexaLib.CallbackEvents.clientResponse, source, requestId, NexaLib.Response.fail('INTERNAL_ERROR', 'Callback failed.'))
        return
    end

    TriggerClientEvent(NexaLib.CallbackEvents.clientResponse, source, requestId, result)
end)

RegisterNetEvent(NexaLib.CallbackEvents.serverResponse, function(requestId, response)
    local source = source
    local pending = NexaLib.ServerCallbacks.pending[requestId]

    if not pending or pending.source ~= source then
        return
    end

    NexaLib.ServerCallbacks.pending[requestId] = nil
    pending.cb(response, source)
end)
