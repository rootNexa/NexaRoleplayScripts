local function notify(source, response)
    TriggerClientEvent(NEXA_DISPATCH_EVENTS.requestResult, source, response)
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

RegisterNetEvent(NEXA_DISPATCH_EVENTS.requestCreateCall, function(payload)
    local source = source

    if not isAllowed(source, NEXA_DISPATCH_EVENTS.requestCreateCall) then
        return
    end

    local valid, code = validateCreateCallPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Notrufdaten.', nil, nil, nil))
        return
    end

    local response = exports.nexa_api['dispatch.createCall'](source, payload)
    notify(source, response)

    if response.success then
        TriggerClientEvent(NEXA_DISPATCH_EVENTS.newCall, source, response.data.call)
    end
end)

RegisterNetEvent(NEXA_DISPATCH_EVENTS.requestAssign, function(payload)
    local source = source

    if not isAllowed(source, NEXA_DISPATCH_EVENTS.requestAssign) then
        return
    end

    local valid, code = validateAssignPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Zuweisungsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['dispatch.assignCall'](source, payload))
end)

RegisterNetEvent(NEXA_DISPATCH_EVENTS.requestStatus, function(payload)
    local source = source

    if not isAllowed(source, NEXA_DISPATCH_EVENTS.requestStatus) then
        return
    end

    local valid, code = validateStatusPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltiger Einsatzstatus.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['dispatch.updateStatus'](source, payload))
end)

RegisterNetEvent(NEXA_DISPATCH_EVENTS.requestPriority, function(payload)
    local source = source

    if not isAllowed(source, NEXA_DISPATCH_EVENTS.requestPriority) then
        return
    end

    local valid, code = validatePriorityPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Prioritaet.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['dispatch.setPriority'](source, payload))
end)
