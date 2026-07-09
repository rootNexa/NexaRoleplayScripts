NexaApiClientCallbacks = {
    handlers = {},
    pendingServer = {},
    nextRequestId = 0
}

local function makeRequestId(name)
    NexaApiClientCallbacks.nextRequestId = NexaApiClientCallbacks.nextRequestId + 1
    return ('server:%s:%s'):format(GetGameTimer(), NexaApiClientCallbacks.nextRequestId)
end

function NexaApiClientCallbacks.RegisterClientCallback(name, handler)
    if not NexaApiValidation.isCallbackName(name) then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Callback name must be prefixed.')
    end

    if type(handler) ~= 'function' then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Callback handler must be a function.')
    end

    NexaApiClientCallbacks.handlers[name] = handler
    return NexaApiResponse.ok(true)
end

function NexaApiClientCallbacks.TriggerServerCallback(name, payload, cb, timeoutMs)
    if not NexaApiValidation.isCallbackName(name) then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Callback name must be prefixed.')
    end

    local requestId = makeRequestId(name)

    NexaApiClientCallbacks.pendingServer[requestId] = {
        cb = cb,
        name = name
    }

    SetTimeout(tonumber(timeoutMs) or NexaApiConfig.callbackTimeoutMs or NexaApiConstants.defaultTimeoutMs, function()
        local pending = NexaApiClientCallbacks.pendingServer[requestId]

        if not pending then
            return
        end

        NexaApiClientCallbacks.pendingServer[requestId] = nil

        if pending.cb then
            pending.cb(NexaApiResponse.fail(NexaApiConstants.errors.timeout, 'Server callback timed out.'))
        end
    end)

    TriggerServerEvent(NexaApiConstants.events.serverRequest, requestId, name, payload)
    return NexaApiResponse.ok({
        requestId = requestId
    })
end

RegisterNetEvent(NexaApiConstants.events.clientRequest, function(requestId, name, payload)
    local handler = NexaApiClientCallbacks.handlers[name]

    if not handler then
        TriggerServerEvent(NexaApiConstants.events.clientResponse, requestId, NexaApiResponse.fail(NexaApiConstants.errors.notFound, 'Client callback is not registered.'))
        return
    end

    local ok, result = pcall(handler, payload)

    if not ok then
        TriggerServerEvent(NexaApiConstants.events.clientResponse, requestId, NexaApiResponse.fail(NexaApiConstants.errors.internal, 'Client callback failed.', result))
        return
    end

    if type(result) == 'table' and result.ok ~= nil then
        TriggerServerEvent(NexaApiConstants.events.clientResponse, requestId, result)
        return
    end

    TriggerServerEvent(NexaApiConstants.events.clientResponse, requestId, NexaApiResponse.ok(result))
end)

RegisterNetEvent(NexaApiConstants.events.serverResponse, function(requestId, response)
    local pending = NexaApiClientCallbacks.pendingServer[requestId]

    if not pending then
        return
    end

    NexaApiClientCallbacks.pendingServer[requestId] = nil

    if pending.cb then
        pending.cb(response)
    end
end)
