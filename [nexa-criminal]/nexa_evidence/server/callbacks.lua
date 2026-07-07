local function rejectRequest(source, eventName)
    if not exports.nexa_security:validateSource(source) then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return exports.nexa_api:buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil)
    end

    return nil
end

lib.callback.register('nexa:evidence:cb:collect', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:evidence:cb:collect')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateEvidenceCollectPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Beweisdaten.', nil, nil, nil)
    end

    return exports.nexa_evidence['evidence.collect'](source, payload)
end)

lib.callback.register('nexa:evidence:cb:list', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:evidence:cb:list')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateEvidenceListPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Beweisanfrage.', nil, nil, nil)
    end

    return exports.nexa_evidence['evidence.list'](source, payload)
end)

lib.callback.register('nexa:evidence:cb:updateStatus', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:evidence:cb:updateStatus')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateEvidenceStatusPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Statusdaten.', nil, nil, nil)
    end

    return exports.nexa_evidence['evidence.updateStatus'](source, payload)
end)
