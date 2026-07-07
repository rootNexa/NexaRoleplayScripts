local function rejectRequest(source, eventName)
    if not exports.nexa_security:validateSource(source) then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return exports.nexa_api:buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil)
    end

    return nil
end

lib.callback.register('nexa:worldstates:cb:get', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:worldstates:cb:get')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateWorldStatePayload(payload, false)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige World-State-Anfrage.', nil, nil, nil)
    end

    return exports.nexa_worldstates['worldstates.getState'](source, payload)
end)

lib.callback.register('nexa:worldstates:cb:list', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:worldstates:cb:list')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateWorldStateListPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige World-State-Liste.', nil, nil, nil)
    end

    return exports.nexa_worldstates['worldstates.listStates'](source, payload)
end)

lib.callback.register('nexa:worldstates:cb:set', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:worldstates:cb:set')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateWorldStatePayload(payload, true)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige World-State-Daten.', nil, nil, nil)
    end

    return exports.nexa_worldstates['worldstates.setState'](source, payload)
end)

lib.callback.register('nexa:worldstates:cb:clear', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:worldstates:cb:clear')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateWorldStatePayload(payload, false)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige World-State-Daten.', nil, nil, nil)
    end

    return exports.nexa_worldstates['worldstates.clearState'](source, payload)
end)

lib.callback.register('nexa:worldstates:cb:resources', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:worldstates:cb:resources')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateResourceStatePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Resource-State-Anfrage.', nil, nil, nil)
    end

    return exports.nexa_worldstates['worldstates.getResourceStates'](source, payload)
end)
