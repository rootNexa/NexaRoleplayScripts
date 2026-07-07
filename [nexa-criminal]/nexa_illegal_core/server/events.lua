local function notify(source, response)
    TriggerClientEvent(NEXA_ILLEGAL_CORE_EVENTS.requestResult, source, response)
end

local function isAllowed(source, eventName)
    if not validateIllegalSource(source) or not exports.nexa_security:validateSource(source) then
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

RegisterNetEvent(NEXA_ILLEGAL_CORE_EVENTS.requestSnapshot, function(payload)
    local source = source

    if not isAllowed(source, NEXA_ILLEGAL_CORE_EVENTS.requestSnapshot) then
        return
    end

    local valid, code = validateSnapshotPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Reputationsanfrage.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_illegal_core['illegal.getSnapshot'](source, payload or {}))
end)

RegisterNetEvent(NEXA_ILLEGAL_CORE_EVENTS.requestContact, function(payload)
    local source = source

    if not isAllowed(source, NEXA_ILLEGAL_CORE_EVENTS.requestContact) then
        return
    end

    if payload ~= nil and type(payload) ~= 'table' then
        notify(source, exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Kontaktanfrage.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_illegal_core['illegal.requestContact'](source))
end)
