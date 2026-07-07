local function notify(source, response)
    TriggerClientEvent(NEXA_FACTIONS_EVENTS.requestResult, source, response)
end

local function featureEnabled()
    if GetResourceState('nexa_featureflags') ~= 'started' then
        return true
    end

    return exports.nexa_featureflags:isEnabled(NexaFactionsConfig.featureFlag)
end

local function isAllowed(source, eventName)
    if not featureEnabled() then
        notify(source, exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Fraktions-Core ist derzeit deaktiviert.', nil, nil, nil))
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

RegisterNetEvent(NEXA_FACTIONS_EVENTS.requestToggleDuty, function(payload)
    local source = source

    if not isAllowed(source, NEXA_FACTIONS_EVENTS.requestToggleDuty) then
        return
    end

    if not validateFactionReferencePayload(payload, true) then
        notify(source, exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Fraktionsdaten.', nil, nil, nil))
        return
    end

    local started = exports.nexa_api['faction.startDuty'](source, payload or {})

    if started.success or started.code ~= 'CONFLICT' then
        notify(source, started)
        return
    end

    notify(source, exports.nexa_api['faction.endDuty'](source, payload or {}))
end)

RegisterNetEvent(NEXA_FACTIONS_EVENTS.requestSetCallsign, function(payload)
    local source = source

    if not isAllowed(source, NEXA_FACTIONS_EVENTS.requestSetCallsign) then
        return
    end

    local valid, code = validateCallsignPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Callsign-Daten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['faction.setCallsign'](source, payload))
end)

RegisterNetEvent(NEXA_FACTIONS_EVENTS.requestAssignMember, function(payload)
    local source = source

    if not isAllowed(source, NEXA_FACTIONS_EVENTS.requestAssignMember) then
        return
    end

    local valid, code = validateAssignMemberPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Mitgliedsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['faction.assignMember'](source, payload))
end)

RegisterNetEvent(NEXA_FACTIONS_EVENTS.requestTransferFunds, function(payload)
    local source = source

    if not isAllowed(source, NEXA_FACTIONS_EVENTS.requestTransferFunds) then
        return
    end

    local valid, code = validateFactionTransferPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Kontodaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['faction.transferFunds'](source, payload))
end)
