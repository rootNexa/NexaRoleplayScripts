local function notify(source, response)
    TriggerClientEvent(NEXA_CHOPSHOP_EVENTS.requestResult, source, response)
end

local function isAllowed(source, eventName)
    if not exports.nexa_security:validateSource(source) then
        notify(source, exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil))
        return false
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        notify(source, exports.nexa_api:buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil))
        return false
    end

    return true
end

RegisterNetEvent(NEXA_CHOPSHOP_EVENTS.requestDismantle, function(payload)
    local source = source

    if not isAllowed(source, NEXA_CHOPSHOP_EVENTS.requestDismantle) then
        return
    end

    local valid, code = validateChopshopDismantlePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Zerlegedaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_chopshop['chopshop.dismantle'](source, payload))
end)

RegisterNetEvent(NEXA_CHOPSHOP_EVENTS.requestSell, function(payload)
    local source = source

    if not isAllowed(source, NEXA_CHOPSHOP_EVENTS.requestSell) then
        return
    end

    local valid, code = validateChopshopSellPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Verkaufsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_chopshop['chopshop.sell'](source, payload))
end)
