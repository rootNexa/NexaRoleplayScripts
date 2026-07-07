local function notify(source, response)
    TriggerClientEvent(NEXA_DRUGS_EVENTS.requestResult, source, response)
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

RegisterNetEvent(NEXA_DRUGS_EVENTS.requestPlant, function(payload)
    local source = source

    if not isAllowed(source, NEXA_DRUGS_EVENTS.requestPlant) then
        return
    end

    local valid, code = validateDrugPlantPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Pflanzdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_drugs['drugs.plant'](source, payload))
end)

RegisterNetEvent(NEXA_DRUGS_EVENTS.requestHarvest, function(payload)
    local source = source

    if not isAllowed(source, NEXA_DRUGS_EVENTS.requestHarvest) then
        return
    end

    local valid, code = validateDrugHarvestPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Erntedaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_drugs['drugs.harvest'](source, payload))
end)

RegisterNetEvent(NEXA_DRUGS_EVENTS.requestProcess, function(payload)
    local source = source

    if not isAllowed(source, NEXA_DRUGS_EVENTS.requestProcess) then
        return
    end

    local valid, code = validateDrugProcessPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Verarbeitungsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_drugs['drugs.process'](source, payload))
end)

RegisterNetEvent(NEXA_DRUGS_EVENTS.requestSell, function(payload)
    local source = source

    if not isAllowed(source, NEXA_DRUGS_EVENTS.requestSell) then
        return
    end

    local valid, code = validateDrugSellPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Verkaufsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_drugs['drugs.sell'](source, payload))
end)
