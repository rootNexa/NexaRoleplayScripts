NexaLib.ClientCallbacks = {
    handlers = {},
    pending = {}
}

local nextRequestId = 0

local function makeRequestId(name)
    nextRequestId = nextRequestId + 1
    return ('client:%s:%s'):format(GetGameTimer(), nextRequestId)
end

function NexaLib.ClientCallbacks.Register(name, handler)
    if type(name) ~= 'string' or name == '' or type(handler) ~= 'function' then
        return false
    end

    NexaLib.ClientCallbacks.handlers[name] = handler
    return true
end

function NexaLib.ClientCallbacks.Trigger(name, payload, cb, timeoutMs)
    if type(name) ~= 'string' or name == '' then
        if cb then
            cb(NexaLib.Response.fail('INVALID_INPUT', 'Callback request is invalid.'))
        end

        return false
    end

    local requestId = makeRequestId(name)

    if cb then
        NexaLib.ClientCallbacks.pending[requestId] = cb

        SetTimeout(timeoutMs or NexaLib.Defaults.callbackTimeoutMs, function()
            local pending = NexaLib.ClientCallbacks.pending[requestId]

            if not pending then
                return
            end

            NexaLib.ClientCallbacks.pending[requestId] = nil
            pending(NexaLib.Response.fail('TIMEOUT', 'Callback timed out.'))
        end)
    end

    TriggerServerEvent(NexaLib.CallbackEvents.clientRequest, requestId, name, payload)
    return true
end

RegisterNetEvent(NexaLib.CallbackEvents.clientResponse, function(requestId, response)
    local cb = NexaLib.ClientCallbacks.pending[requestId]

    if not cb then
        return
    end

    NexaLib.ClientCallbacks.pending[requestId] = nil
    cb(response)
end)

RegisterNetEvent(NexaLib.CallbackEvents.serverRequest, function(requestId, name, payload)
    if type(requestId) ~= 'string' or type(name) ~= 'string' then
        return
    end

    local handler = NexaLib.ClientCallbacks.handlers[name]

    if not handler then
        TriggerServerEvent(NexaLib.CallbackEvents.serverResponse, requestId, NexaLib.Response.fail('NOT_FOUND', 'Callback is not registered.'))
        return
    end

    local ok, result = pcall(handler, payload)

    if not ok then
        NexaLib.Logger.error('nexa-lib', 'Client callback failed.', {
            name = name,
            error = result
        })
        TriggerServerEvent(NexaLib.CallbackEvents.serverResponse, requestId, NexaLib.Response.fail('INTERNAL_ERROR', 'Callback failed.'))
        return
    end

    TriggerServerEvent(NexaLib.CallbackEvents.serverResponse, requestId, result)
end)
