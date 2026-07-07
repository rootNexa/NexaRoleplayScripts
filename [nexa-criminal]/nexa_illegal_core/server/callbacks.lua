local function rejectRequest(source, eventName)
    if not validateIllegalSource(source) or not exports.nexa_security:validateSource(source) then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return exports.nexa_api:buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil)
    end

    return nil
end

lib.callback.register('nexa:illegal_core:cb:getSnapshot', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:illegal_core:cb:getSnapshot')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateSnapshotPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Reputationsanfrage.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.getSnapshot'](source, payload or {})
end)

lib.callback.register('nexa:illegal_core:cb:adjustReputation', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:illegal_core:cb:adjustReputation')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateReputationPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Reputationsdaten.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.adjustReputation'](source, payload)
end)

lib.callback.register('nexa:illegal_core:cb:checkCooldown', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:illegal_core:cb:checkCooldown')

    if rejected ~= nil then
        return rejected
    end

    if type(payload) ~= 'table' then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Cooldown-Anfrage.', nil, nil, nil)
    end

    local characterId = getIllegalActiveCharacterId(source)

    if characterId == nil then
        return exports.nexa_api:buildResponse(false, 'CHARACTER_NOT_LOADED', 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.checkCooldown'](source, characterId, payload.action)
end)
