local function notify(source, response)
    TriggerClientEvent(NEXA_JOBS_EVENTS.requestResult, source, response)
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

RegisterNetEvent(NEXA_JOBS_EVENTS.requestToggleDuty, function(payload)
    local source = source

    if not isAllowed(source, NEXA_JOBS_EVENTS.requestToggleDuty) then
        return
    end

    local valid, code = validateJobReferencePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Dienstdaten.', nil, nil, nil))
        return
    end

    local started = exports.nexa_api['job.startDuty'](source, payload or {})

    if started.success or started.code ~= 'CONFLICT' then
        notify(source, started)
        return
    end

    notify(source, exports.nexa_api['job.endDuty'](source, payload or {}))
end)

RegisterNetEvent(NEXA_JOBS_EVENTS.requestSalary, function(payload)
    local source = source

    if not isAllowed(source, NEXA_JOBS_EVENTS.requestSalary) then
        return
    end

    local valid, code = validateJobReferencePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Gehaltsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['job.paySalary'](source, payload or {}))
end)
