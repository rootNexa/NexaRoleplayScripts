local function notify(source, response)
    TriggerClientEvent(NEXA_MONEYWASH_EVENTS.requestResult, source, response)
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

RegisterNetEvent(NEXA_MONEYWASH_EVENTS.requestWash, function(payload)
    local source = source

    if not isAllowed(source, NEXA_MONEYWASH_EVENTS.requestWash) then
        return
    end

    local valid, code = validateMoneywashPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Waschdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_moneywash['moneywash.wash'](source, payload))
end)
