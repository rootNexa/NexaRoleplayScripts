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

lib.callback.register('nexa:moneywash:cb:wash', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:moneywash:cb:wash')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateMoneywashPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Waschdaten.', nil, nil, nil)
    end

    return exports.nexa_moneywash['moneywash.wash'](source, payload)
end)
