NexaApiCallbacks = {
    serverHandlers = {},
    pendingClient = {},
    nextRequestId = 0
}

local function makeRequestId(prefix, name)
    NexaApiCallbacks.nextRequestId = NexaApiCallbacks.nextRequestId + 1
    return ('%s:%s:%s'):format(prefix, GetGameTimer(), NexaApiCallbacks.nextRequestId)
end

function NexaApiCallbacks.RegisterServerCallback(name, handler, options)
    if not NexaApiValidation.isCallbackName(name) then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Callback name must be prefixed.')
    end

    if type(handler) ~= 'function' then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Callback handler must be a function.')
    end

    NexaApiCallbacks.serverHandlers[name] = {
        handler = handler,
        options = options or {}
    }

    return NexaApiResponse.ok(true)
end

function NexaApiCallbacks.TriggerServerCallback(name, source, payload)
    source = tonumber(source)

    if not source or source <= 0 or not NexaApiValidation.isCallbackName(name) then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Server callback request is invalid.')
    end

    local entry = NexaApiCallbacks.serverHandlers[name]

    if not entry then
        return NexaApiResponse.fail(NexaApiConstants.errors.notFound, 'Server callback is not registered.')
    end

    local ok, result = pcall(entry.handler, source, payload)

    if not ok then
        return NexaApiResponse.fail(NexaApiConstants.errors.internal, 'Server callback failed.', result)
    end

    if type(result) == 'table' and result.ok ~= nil then
        return result
    end

    return NexaApiResponse.ok(result)
end

function NexaApiCallbacks.RegisterClientCallback(name, targetSource, handlerName, payload, timeoutMs, cb)
    targetSource = tonumber(targetSource)

    if not targetSource or targetSource <= 0 or not NexaApiValidation.isCallbackName(name) then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Client callback request is invalid.')
    end

    if type(handlerName) ~= 'string' or handlerName == '' then
        handlerName = name
    end

    local requestId = makeRequestId(('client:%s'):format(targetSource), name)
    local timeout = tonumber(timeoutMs) or NexaApiConfig.callbackTimeoutMs or NexaApiConstants.defaultTimeoutMs

    NexaApiCallbacks.pendingClient[requestId] = {
        source = targetSource,
        cb = cb,
        name = name
    }

    SetTimeout(timeout, function()
        local pending = NexaApiCallbacks.pendingClient[requestId]

        if not pending then
            return
        end

        NexaApiCallbacks.pendingClient[requestId] = nil

        if pending.cb then
            pending.cb(NexaApiResponse.fail(NexaApiConstants.errors.timeout, 'Client callback timed out.'))
        end
    end)

    TriggerClientEvent(NexaApiConstants.events.clientRequest, targetSource, requestId, handlerName, payload)
    return NexaApiResponse.ok({
        requestId = requestId
    })
end

RegisterNetEvent(NexaApiConstants.events.serverRequest, function(requestId, name, payload)
    local requestSource = source
    local response = NexaApiCallbacks.TriggerServerCallback(name, requestSource, payload)

    TriggerClientEvent(NexaApiConstants.events.serverResponse, requestSource, requestId, response)
end)

RegisterNetEvent(NexaApiConstants.events.clientResponse, function(requestId, response)
    local requestSource = source
    local pending = NexaApiCallbacks.pendingClient[requestId]

    if not pending or pending.source ~= requestSource then
        return
    end

    NexaApiCallbacks.pendingClient[requestId] = nil

    if pending.cb then
        pending.cb(response)
    end
end)
