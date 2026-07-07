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

lib.callback.register('nexa:licenses:cb:listTypes', function(source)
    local rejected = checkRequest(source, 'nexa:licenses:cb:listTypes')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_api:listLicenseTypes()
end)

lib.callback.register('nexa:licenses:cb:issueLicense', function(source, payload)
    local rejected = checkRequest(source, 'nexa:licenses:cb:issueLicense')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateLicenseIssuePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Lizenzdaten.', nil, nil, nil)
    end

    return exports.nexa_api:issueLicense(source, payload)
end)

lib.callback.register('nexa:licenses:cb:revokeLicense', function(source, payload)
    local rejected = checkRequest(source, 'nexa:licenses:cb:revokeLicense')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateLicenseRevokePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Lizenzdaten.', nil, nil, nil)
    end

    return exports.nexa_api:revokeLicense(source, payload)
end)

lib.callback.register('nexa:licenses:cb:validateLicense', function(source, payload)
    local rejected = checkRequest(source, 'nexa:licenses:cb:validateLicense')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateLicenseValidationPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Lizenzdaten.', nil, nil, nil)
    end

    return exports.nexa_api:validateLicense(payload)
end)

lib.callback.register('nexa:licenses:cb:getHistory', function(source, payload)
    local rejected = checkRequest(source, 'nexa:licenses:cb:getHistory')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateLicenseHistoryPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Lizenz.', nil, nil, nil)
    end

    return exports.nexa_api:getLicenseHistory(payload)
end)
