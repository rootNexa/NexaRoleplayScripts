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

lib.callback.register('nexa:blackmarket:cb:getCatalog', function(source)
    local rejected = rejectRequest(source, 'nexa:blackmarket:cb:getCatalog')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_blackmarket['blackmarket.getCatalog'](source)
end)

lib.callback.register('nexa:blackmarket:cb:buy', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:blackmarket:cb:buy')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateBlackmarketPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Kaufdaten.', nil, nil, nil)
    end

    return exports.nexa_blackmarket['blackmarket.buy'](source, payload)
end)

lib.callback.register('nexa:blackmarket:cb:sell', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:blackmarket:cb:sell')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateBlackmarketPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Verkaufsdaten.', nil, nil, nil)
    end

    return exports.nexa_blackmarket['blackmarket.sell'](source, payload)
end)
