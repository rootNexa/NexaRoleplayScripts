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

lib.callback.register('nexa:zones:cb:getAvailable', function(source)
    local rejected = rejectRequest(source, 'nexa:zones:cb:getAvailable')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_zones['zones.getAvailable'](source)
end)

lib.callback.register('nexa:zones:cb:validateCriticalAction', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:zones:cb:validateCriticalAction')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_zones['zones.validateCriticalAction'](source, payload or {})
end)
