local function notify(source, response)
    TriggerClientEvent(NEXA_EMS_EVENTS.requestResult, source, response)
end

local function featureEnabled()
    if GetResourceState('nexa_featureflags') ~= 'started' then
        return true
    end

    return exports.nexa_featureflags:isEnabled(NexaEmsConfig.featureFlag)
end

local function isAllowed(source, eventName)
    if not featureEnabled() then
        notify(source, exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'EMS ist derzeit deaktiviert.', nil, nil, nil))
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

RegisterNetEvent(NEXA_EMS_EVENTS.requestToggleDuty, function()
    local source = source

    if not isAllowed(source, NEXA_EMS_EVENTS.requestToggleDuty) then
        return
    end

    local started = exports.nexa_api['faction.startDuty'](source, {
        factionName = NexaEmsConfig.factionName
    })

    if started.success or started.code ~= 'CONFLICT' then
        notify(source, started)
        return
    end

    notify(source, exports.nexa_api['faction.endDuty'](source, {
        factionName = NexaEmsConfig.factionName
    }))
end)

RegisterNetEvent(NEXA_EMS_EVENTS.requestSetCallsign, function(payload)
    local source = source

    if not isAllowed(source, NEXA_EMS_EVENTS.requestSetCallsign) then
        return
    end

    local valid, code = validateEmsCallsignPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Callsign-Daten.', nil, nil, nil))
        return
    end

    local request = payload or {}
    request.factionName = NexaEmsConfig.factionName

    notify(source, exports.nexa_api['faction.setCallsign'](source, request))
end)

RegisterNetEvent(NEXA_EMS_EVENTS.requestCreateRecord, function(payload)
    local source = source

    if not isAllowed(source, NEXA_EMS_EVENTS.requestCreateRecord) then
        return
    end

    local valid, code = validateEmsCreateRecordPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Patientenakten-Daten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['ems.createRecord'](source, payload))
end)

RegisterNetEvent(NEXA_EMS_EVENTS.requestAddTreatment, function(payload)
    local source = source

    if not isAllowed(source, NEXA_EMS_EVENTS.requestAddTreatment) then
        return
    end

    local valid, code = validateEmsTreatmentPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Behandlungsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['ems.addTreatment'](source, payload))
end)

RegisterNetEvent(NEXA_EMS_EVENTS.requestCreateInvoice, function(payload)
    local source = source

    if not isAllowed(source, NEXA_EMS_EVENTS.requestCreateInvoice) then
        return
    end

    local valid, code = validateEmsInvoicePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Rechnungsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['account.createMedicalInvoice'](source, payload))
end)
