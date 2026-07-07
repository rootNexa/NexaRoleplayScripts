local function notify(source, response)
    TriggerClientEvent(NEXA_WEAZEL_EVENTS.requestResult, source, response)
end

local function featureEnabled()
    if GetResourceState('nexa_featureflags') ~= 'started' then
        return true
    end

    return exports.nexa_featureflags:isEnabled(NexaWeazelConfig.featureFlag)
end

local function isAllowed(source, eventName)
    if not featureEnabled() then
        notify(source, exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Weazel ist derzeit deaktiviert.', nil, nil, nil))
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

RegisterNetEvent(NEXA_WEAZEL_EVENTS.requestToggleDuty, function()
    local source = source

    if not isAllowed(source, NEXA_WEAZEL_EVENTS.requestToggleDuty) then
        return
    end

    local started = exports.nexa_api['faction.startDuty'](source, {
        factionName = NexaWeazelConfig.factionName
    })

    if started.success or started.code ~= 'CONFLICT' then
        notify(source, started)
        return
    end

    notify(source, exports.nexa_api['faction.endDuty'](source, {
        factionName = NexaWeazelConfig.factionName
    }))
end)

RegisterNetEvent(NEXA_WEAZEL_EVENTS.requestSetCallsign, function(payload)
    local source = source

    if not isAllowed(source, NEXA_WEAZEL_EVENTS.requestSetCallsign) then
        return
    end

    local valid, code = validateWeazelCallsignPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Callsign-Daten.', nil, nil, nil))
        return
    end

    local request = payload or {}
    request.factionName = NexaWeazelConfig.factionName

    notify(source, exports.nexa_api['faction.setCallsign'](source, request))
end)

RegisterNetEvent(NEXA_WEAZEL_EVENTS.requestIssuePressPass, function(payload)
    local source = source

    if not isAllowed(source, NEXA_WEAZEL_EVENTS.requestIssuePressPass) then
        return
    end

    local valid, code = validateWeazelPressPassPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Presseausweis-Daten.', nil, nil, nil))
        return
    end

    notify(source, NexaWeazelIssuePressPass(source, payload))
end)

RegisterNetEvent(NEXA_WEAZEL_EVENTS.requestCreateAnnouncement, function(payload)
    local source = source

    if not isAllowed(source, NEXA_WEAZEL_EVENTS.requestCreateAnnouncement) then
        return
    end

    local valid, code = validateWeazelAnnouncementPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Ankuendigungsdaten.', nil, nil, nil))
        return
    end

    notify(source, NexaWeazelCreateAnnouncement(source, payload))
end)
