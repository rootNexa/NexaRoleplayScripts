local function notify(source, response)
    TriggerClientEvent(NEXA_BANKING_EVENTS.requestResult, source, response)
end

local function isAllowed(source, eventName)
    local sourceValid = exports.nexa_security:validateSource(source)

    if not sourceValid then
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

RegisterNetEvent(NEXA_BANKING_EVENTS.requestCreatePrivateAccount, function(payload)
    local source = source

    if not isAllowed(source, NEXA_BANKING_EVENTS.requestCreatePrivateAccount) then
        return
    end

    local valid, code = validateCreatePrivateAccountPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Kontodaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api:createPrivateAccount(source, payload or {}))
end)

RegisterNetEvent(NEXA_BANKING_EVENTS.requestTransfer, function(payload)
    local source = source

    if not isAllowed(source, NEXA_BANKING_EVENTS.requestTransfer) then
        return
    end

    local valid, code = validateTransferPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Ueberweisungsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api:transferMoney(source, payload))
end)

RegisterNetEvent(NEXA_BANKING_EVENTS.requestPayInvoice, function(payload)
    local source = source

    if not isAllowed(source, NEXA_BANKING_EVENTS.requestPayInvoice) then
        return
    end

    local valid, code = validatePayInvoicePayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Rechnungsdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api:payInvoice(source, payload))
end)
