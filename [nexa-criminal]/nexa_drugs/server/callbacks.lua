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

lib.callback.register('nexa:drugs:cb:plant', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:drugs:cb:plant')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateDrugPlantPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Pflanzdaten.', nil, nil, nil)
    end

    return exports.nexa_drugs['drugs.plant'](source, payload)
end)

lib.callback.register('nexa:drugs:cb:harvest', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:drugs:cb:harvest')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateDrugHarvestPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Erntedaten.', nil, nil, nil)
    end

    return exports.nexa_drugs['drugs.harvest'](source, payload)
end)

lib.callback.register('nexa:drugs:cb:process', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:drugs:cb:process')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateDrugProcessPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Verarbeitungsdaten.', nil, nil, nil)
    end

    return exports.nexa_drugs['drugs.process'](source, payload)
end)

lib.callback.register('nexa:drugs:cb:sell', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:drugs:cb:sell')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateDrugSellPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Verkaufsdaten.', nil, nil, nil)
    end

    return exports.nexa_drugs['drugs.sell'](source, payload)
end)
