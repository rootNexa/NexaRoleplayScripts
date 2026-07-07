local function checkRequest(source, eventName)
    if not exports.nexa_security:validateSource(source) then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return exports.nexa_api:buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil)
    end

    return nil
end

lib.callback.register('nexa:dispatch:cb:createCall', function(source, payload)
    local rejected = checkRequest(source, NEXA_DISPATCH_EVENTS.requestCreateCall)

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateCreateCallPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Notrufdaten.', nil, nil, nil)
    end

    return exports.nexa_api['dispatch.createCall'](source, payload)
end)

lib.callback.register('nexa:dispatch:cb:listCalls', function(source, payload)
    local rejected = checkRequest(source, 'nexa:dispatch:cb:listCalls')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateListCallsPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Filterdaten.', nil, nil, nil)
    end

    return exports.nexa_api['dispatch.listCalls'](source, payload or {})
end)

lib.callback.register('nexa:dispatch:cb:assignCall', function(source, payload)
    local rejected = checkRequest(source, 'nexa:dispatch:cb:assignCall')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateAssignPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Zuweisungsdaten.', nil, nil, nil)
    end

    return exports.nexa_api['dispatch.assignCall'](source, payload)
end)

lib.callback.register('nexa:dispatch:cb:updateStatus', function(source, payload)
    local rejected = checkRequest(source, 'nexa:dispatch:cb:updateStatus')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateStatusPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltiger Einsatzstatus.', nil, nil, nil)
    end

    return exports.nexa_api['dispatch.updateStatus'](source, payload)
end)

lib.callback.register('nexa:dispatch:cb:setPriority', function(source, payload)
    local rejected = checkRequest(source, 'nexa:dispatch:cb:setPriority')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validatePriorityPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Prioritaet.', nil, nil, nil)
    end

    return exports.nexa_api['dispatch.setPriority'](source, payload)
end)
