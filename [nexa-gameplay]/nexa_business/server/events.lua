local function notify(source, response)
    TriggerClientEvent(NEXA_BUSINESS_EVENTS.requestResult, source, response)
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

RegisterNetEvent(NEXA_BUSINESS_EVENTS.requestCreate, function(payload)
    local source = source

    if not isAllowed(source, NEXA_BUSINESS_EVENTS.requestCreate) then
        return
    end

    local valid, code = validateCreateBusinessPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Firmendaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['business.create'](source, payload))
end)

RegisterNetEvent(NEXA_BUSINESS_EVENTS.requestTransfer, function(payload)
    local source = source

    if not isAllowed(source, NEXA_BUSINESS_EVENTS.requestTransfer) then
        return
    end

    local valid, code = validateBusinessTransferPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Transaktionsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['business.transfer'](source, payload))
end)

RegisterNetEvent(NEXA_BUSINESS_EVENTS.requestAddMember, function(payload)
    local source = source

    if not isAllowed(source, NEXA_BUSINESS_EVENTS.requestAddMember) then
        return
    end

    local valid, code = validateBusinessMemberPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Mitgliedsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['business.addMember'](source, payload))
end)

RegisterNetEvent(NEXA_BUSINESS_EVENTS.requestRemoveMember, function(payload)
    local source = source

    if not isAllowed(source, NEXA_BUSINESS_EVENTS.requestRemoveMember) then
        return
    end

    local valid, code = validateBusinessMemberPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Mitgliedsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api['business.removeMember'](source, payload))
end)
