local function responseFail(code, message, details)
    return {
        ok = false,
        success = false,
        data = nil,
        error = {
            code = code,
            message = message,
            details = details
        },
        code = code,
        message = message,
        meta = details
    }
end

local function notify(source, response)
    TriggerClientEvent(NEXA_WORLDSTATES_EVENTS.requestResult, source, response)
end

local function isAllowed(source, eventName)
    if not exports.nexa_security:validateSource(source) then
        notify(source, responseFail('INVALID_INPUT', 'Ungueltige Anfrage.', nil))
        return false
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        notify(source, responseFail('RATE_LIMITED', 'Bitte warte einen Moment.', nil))
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
        notify(source, responseFail(code, 'Ungueltige World-State-Daten.', nil))
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
        notify(source, responseFail(code, 'Ungueltige World-State-Daten.', nil))
        return
    end

    notify(source, exports.nexa_worldstates['worldstates.clearState'](source, payload))
end)
