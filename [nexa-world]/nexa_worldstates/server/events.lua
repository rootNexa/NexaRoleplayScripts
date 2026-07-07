local function notify(source, response)
    TriggerClientEvent(NEXA_WORLDSTATES_EVENTS.requestResult, source, response)
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

RegisterNetEvent(NEXA_WORLDSTATES_EVENTS.requestSet, function(payload)
    local source = source

    if not isAllowed(source, NEXA_WORLDSTATES_EVENTS.requestSet) then
        return
    end

    local valid, code = validateWorldStatePayload(payload, true)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige World-State-Daten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_worldstates['worldstates.setState'](source, payload))
end)

RegisterNetEvent(NEXA_WORLDSTATES_EVENTS.requestClear, function(payload)
    local source = source

    if not isAllowed(source, NEXA_WORLDSTATES_EVENTS.requestClear) then
        return
    end

    local valid, code = validateWorldStatePayload(payload, false)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige World-State-Daten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_worldstates['worldstates.clearState'](source, payload))
end)
