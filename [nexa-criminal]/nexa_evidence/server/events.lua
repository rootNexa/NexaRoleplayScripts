local function notify(source, response)
    TriggerClientEvent(NEXA_EVIDENCE_EVENTS.requestResult, source, response)
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

RegisterNetEvent(NEXA_EVIDENCE_EVENTS.requestCollect, function(payload)
    local source = source

    if not isAllowed(source, NEXA_EVIDENCE_EVENTS.requestCollect) then
        return
    end

    local valid, code = validateEvidenceCollectPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Beweisdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_evidence['evidence.collect'](source, payload))
end)

RegisterNetEvent(NEXA_EVIDENCE_EVENTS.requestStatus, function(payload)
    local source = source

    if not isAllowed(source, NEXA_EVIDENCE_EVENTS.requestStatus) then
        return
    end

    local valid, code = validateEvidenceStatusPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Statusdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_evidence['evidence.updateStatus'](source, payload))
end)
