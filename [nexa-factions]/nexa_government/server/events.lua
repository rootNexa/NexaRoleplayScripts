local function notify(source, response)
    TriggerClientEvent(NEXA_GOVERNMENT_EVENTS.requestResult, source, response)
end

local function featureEnabled()
    if GetResourceState('nexa_featureflags') ~= 'started' then
        return true
    end

    return exports.nexa_featureflags:isEnabled(NexaGovernmentConfig.featureFlag)
end

local function isAllowed(source, eventName)
    if not featureEnabled() then
        notify(source, exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Government ist derzeit deaktiviert.', nil, nil, nil))
        return false
    end

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

RegisterNetEvent(NEXA_GOVERNMENT_EVENTS.requestToggleDuty, function()
    local source = source

    if not isAllowed(source, NEXA_GOVERNMENT_EVENTS.requestToggleDuty) then
        return
    end

    local started = exports.nexa_api['faction.startDuty'](source, {
        factionName = NexaGovernmentConfig.factionName
    })

    if started.success or started.code ~= 'CONFLICT' then
        notify(source, started)
        return
    end

    notify(source, exports.nexa_api['faction.endDuty'](source, {
        factionName = NexaGovernmentConfig.factionName
    }))
end)

RegisterNetEvent(NEXA_GOVERNMENT_EVENTS.requestSetCallsign, function(payload)
    local source = source

    if not isAllowed(source, NEXA_GOVERNMENT_EVENTS.requestSetCallsign) then
        return
    end

    local valid, code = validateGovernmentCallsignPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Callsign-Daten.', nil, nil, nil))
        return
    end

    local request = payload or {}
    request.factionName = NexaGovernmentConfig.factionName

    notify(source, exports.nexa_api['faction.setCallsign'](source, request))
end)

RegisterNetEvent(NEXA_GOVERNMENT_EVENTS.requestIssueDocument, function(payload)
    local source = source

    if not isAllowed(source, NEXA_GOVERNMENT_EVENTS.requestIssueDocument) then
        return
    end

    local valid, code = validateGovernmentDocumentIssuePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Dokumentdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['document.issue'](source, payload))
end)

RegisterNetEvent(NEXA_GOVERNMENT_EVENTS.requestRevokeDocument, function(payload)
    local source = source

    if not isAllowed(source, NEXA_GOVERNMENT_EVENTS.requestRevokeDocument) then
        return
    end

    local valid, code = validateGovernmentDocumentRevokePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Dokumentdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['document.revoke'](source, payload))
end)

RegisterNetEvent(NEXA_GOVERNMENT_EVENTS.requestIssueLicense, function(payload)
    local source = source

    if not isAllowed(source, NEXA_GOVERNMENT_EVENTS.requestIssueLicense) then
        return
    end

    local valid, code = validateGovernmentLicenseIssuePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Lizenzdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['license.issue'](source, payload))
end)

RegisterNetEvent(NEXA_GOVERNMENT_EVENTS.requestRevokeLicense, function(payload)
    local source = source

    if not isAllowed(source, NEXA_GOVERNMENT_EVENTS.requestRevokeLicense) then
        return
    end

    local valid, code = validateGovernmentLicenseRevokePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Lizenzdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['license.revoke'](source, payload))
end)

RegisterNetEvent(NEXA_GOVERNMENT_EVENTS.requestCreateInvoice, function(payload)
    local source = source

    if not isAllowed(source, NEXA_GOVERNMENT_EVENTS.requestCreateInvoice) then
        return
    end

    local valid, code = validateGovernmentInvoicePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Gebuehrendaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['account.createGovernmentInvoice'](source, payload))
end)
