local function notify(source, response)
    TriggerClientEvent(NEXA_LICENSES_EVENTS.requestResult, source, response)
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

RegisterNetEvent(NEXA_LICENSES_EVENTS.requestIssueLicense, function(payload)
    local source = source

    if not isAllowed(source, NEXA_LICENSES_EVENTS.requestIssueLicense) then
        return
    end

    local valid, code = validateLicenseIssuePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Lizenzdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api:issueLicense(source, payload))
end)

RegisterNetEvent(NEXA_LICENSES_EVENTS.requestRevokeLicense, function(payload)
    local source = source

    if not isAllowed(source, NEXA_LICENSES_EVENTS.requestRevokeLicense) then
        return
    end

    local valid, code = validateLicenseRevokePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Lizenzdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api:revokeLicense(source, payload))
end)

RegisterNetEvent(NEXA_LICENSES_EVENTS.requestValidateLicense, function(payload)
    local source = source

    if not isAllowed(source, NEXA_LICENSES_EVENTS.requestValidateLicense) then
        return
    end

    local valid, code = validateLicenseValidationPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Lizenzdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api:validateLicense(payload))
end)
