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

lib.callback.register('nexa:chopshop:cb:dismantle', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:chopshop:cb:dismantle')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateChopshopDismantlePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Zerlegedaten.', nil, nil, nil)
    end

    return exports.nexa_chopshop['chopshop.dismantle'](source, payload)
end)

lib.callback.register('nexa:chopshop:cb:sell', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:chopshop:cb:sell')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateChopshopSellPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Verkaufsdaten.', nil, nil, nil)
    end

    return exports.nexa_chopshop['chopshop.sell'](source, payload)
end)
