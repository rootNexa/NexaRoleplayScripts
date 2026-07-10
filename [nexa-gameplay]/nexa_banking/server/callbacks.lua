local function checkRequest(source, eventName)
    local sourceValid = exports.nexa_security:validateSource(source)

    if not sourceValid then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return exports.nexa_api:buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil)
    end

    return nil
end

exports.nexa_api:RegisterServerCallback('nexa:banking:cb:getAccounts', function(source)
    local rejected = checkRequest(source, 'nexa:banking:cb:getAccounts')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_api:listAccounts(source)
end)

exports.nexa_api:RegisterServerCallback('nexa:banking:cb:createPrivateAccount', function(source, payload)
    local rejected = checkRequest(source, 'nexa:banking:cb:createPrivateAccount')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateCreatePrivateAccountPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Kontodaten.', nil, nil, nil)
    end

    return exports.nexa_api:createPrivateAccount(source, payload or {})
end)

exports.nexa_api:RegisterServerCallback('nexa:banking:cb:getTransactions', function(source, payload)
    local rejected = checkRequest(source, 'nexa:banking:cb:getTransactions')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateAccountReferencePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Kontodaten.', nil, nil, nil)
    end

    return exports.nexa_api:getAccountTransactions(source, payload)
end)

exports.nexa_api:RegisterServerCallback('nexa:banking:cb:requestTransfer', function(source, payload)
    local rejected = checkRequest(source, 'nexa:banking:cb:requestTransfer')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateTransferPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Ueberweisungsdaten.', nil, nil, nil)
    end

    return exports.nexa_api:transferMoney(source, payload)
end)

exports.nexa_api:RegisterServerCallback('nexa:banking:cb:getInvoices', function(source, payload)
    local rejected = checkRequest(source, 'nexa:banking:cb:getInvoices')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_api:listInvoices(source, payload or {})
end)

exports.nexa_api:RegisterServerCallback('nexa:banking:cb:payInvoice', function(source, payload)
    local rejected = checkRequest(source, 'nexa:banking:cb:payInvoice')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validatePayInvoicePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Rechnungsdaten.', nil, nil, nil)
    end

    return exports.nexa_api:payInvoice(source, payload)
end)
