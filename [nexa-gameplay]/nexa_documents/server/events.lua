local function notify(source, response)
    TriggerClientEvent(NEXA_DOCUMENTS_EVENTS.requestResult, source, response)
end

local function isAllowed(source, eventName)
    local sourceValid = exports.nexa_security:validateSource(source)

    if not sourceValid then
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

RegisterNetEvent(NEXA_DOCUMENTS_EVENTS.requestIssueDocument, function(payload)
    local source = source

    if not isAllowed(source, NEXA_DOCUMENTS_EVENTS.requestIssueDocument) then
        return
    end

    local valid, code = validateDocumentIssuePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Dokumentdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api:issueDocument(source, payload))
end)

RegisterNetEvent(NEXA_DOCUMENTS_EVENTS.requestRevokeDocument, function(payload)
    local source = source

    if not isAllowed(source, NEXA_DOCUMENTS_EVENTS.requestRevokeDocument) then
        return
    end

    local valid, code = validateDocumentRevokePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Dokumentdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api:revokeDocument(source, payload))
end)

RegisterNetEvent(NEXA_DOCUMENTS_EVENTS.requestValidateDocument, function(payload)
    local source = source

    if not isAllowed(source, NEXA_DOCUMENTS_EVENTS.requestValidateDocument) then
        return
    end

    local valid, code = validateDocumentValidationPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltiges Dokument.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api:validateDocument(payload))
end)
