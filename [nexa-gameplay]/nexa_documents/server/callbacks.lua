local function checkRequest(source, eventName)
    local sourceValid = exports.nexa_security:validateSource(source)

    if not sourceValid then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return exports.nexa_api:buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil)
    end

    return nil
end

exports.nexa_api:RegisterServerCallback('nexa:documents:cb:listTypes', function(source)
    local rejected = checkRequest(source, 'nexa:documents:cb:listTypes')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_api:listDocumentTypes()
end)

exports.nexa_api:RegisterServerCallback('nexa:documents:cb:issueDocument', function(source, payload)
    local rejected = checkRequest(source, 'nexa:documents:cb:issueDocument')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateDocumentIssuePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Dokumentdaten.', nil, nil, nil)
    end

    return exports.nexa_api:issueDocument(source, payload)
end)

exports.nexa_api:RegisterServerCallback('nexa:documents:cb:revokeDocument', function(source, payload)
    local rejected = checkRequest(source, 'nexa:documents:cb:revokeDocument')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateDocumentRevokePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Dokumentdaten.', nil, nil, nil)
    end

    return exports.nexa_api:revokeDocument(source, payload)
end)

exports.nexa_api:RegisterServerCallback('nexa:documents:cb:validateDocument', function(source, payload)
    local rejected = checkRequest(source, 'nexa:documents:cb:validateDocument')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateDocumentValidationPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltiges Dokument.', nil, nil, nil)
    end

    return exports.nexa_api:validateDocument(payload)
end)

exports.nexa_api:RegisterServerCallback('nexa:documents:cb:createDigitalDocument', function(source, payload)
    local rejected = checkRequest(source, 'nexa:documents:cb:createDigitalDocument')

    if rejected ~= nil then
        return rejected
    end

    return CreateDigitalDocument(payload)
end)

exports.nexa_api:RegisterServerCallback('nexa:documents:cb:signDocument', function(source, payload)
    local rejected = checkRequest(source, 'nexa:documents:cb:signDocument')

    if rejected ~= nil then
        return rejected
    end

    payload = type(payload) == 'table' and payload or {}
    return SignDocument(payload.document_id, payload)
end)

exports.nexa_api:RegisterServerCallback('nexa:documents:cb:shareDocument', function(source, payload)
    local rejected = checkRequest(source, 'nexa:documents:cb:shareDocument')

    if rejected ~= nil then
        return rejected
    end

    payload = type(payload) == 'table' and payload or {}
    return ShareDocument(payload.document_id, payload)
end)
