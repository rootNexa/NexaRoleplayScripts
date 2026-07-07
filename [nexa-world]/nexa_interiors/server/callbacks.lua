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

lib.callback.register('nexa:interiors:cb:getAvailable', function(source)
    local rejected = rejectRequest(source, 'nexa:interiors:cb:getAvailable')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_interiors['interiors.getAvailable'](source)
end)

lib.callback.register('nexa:interiors:cb:validateAccess', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:interiors:cb:validateAccess')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_interiors['interiors.validateAccess'](source, payload or {})
end)
