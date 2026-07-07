local function checkRequest(source, eventName)
    if not exports.nexa_security:validateSource(source) then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return exports.nexa_api:buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil)
    end

    return nil
end

lib.callback.register('nexa:business:cb:listBusinesses', function(source)
    local rejected = checkRequest(source, 'nexa:business:cb:listBusinesses')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_api['business.list'](source)
end)

lib.callback.register('nexa:business:cb:createBusiness', function(source, payload)
    local rejected = checkRequest(source, 'nexa:business:cb:createBusiness')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateCreateBusinessPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Firmendaten.', nil, nil, nil)
    end

    return exports.nexa_api['business.create'](source, payload)
end)

lib.callback.register('nexa:business:cb:addMember', function(source, payload)
    local rejected = checkRequest(source, 'nexa:business:cb:addMember')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateBusinessMemberPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Mitgliedsdaten.', nil, nil, nil)
    end

    return exports.nexa_api['business.addMember'](source, payload)
end)

lib.callback.register('nexa:business:cb:removeMember', function(source, payload)
    local rejected = checkRequest(source, 'nexa:business:cb:removeMember')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateBusinessMemberPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Mitgliedsdaten.', nil, nil, nil)
    end

    return exports.nexa_api['business.removeMember'](source, payload)
end)

lib.callback.register('nexa:business:cb:listAccounts', function(source, payload)
    local rejected = checkRequest(source, 'nexa:business:cb:listAccounts')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateBusinessReferencePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Firmendaten.', nil, nil, nil)
    end

    return exports.nexa_api['business.listAccounts'](source, payload)
end)

lib.callback.register('nexa:business:cb:requestTransfer', function(source, payload)
    local rejected = checkRequest(source, 'nexa:business:cb:requestTransfer')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateBusinessTransferPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Transaktionsdaten.', nil, nil, nil)
    end

    return exports.nexa_api['business.transfer'](source, payload)
end)

lib.callback.register('nexa:business:cb:listTransactions', function(source, payload)
    local rejected = checkRequest(source, 'nexa:business:cb:listTransactions')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateBusinessReferencePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Firmendaten.', nil, nil, nil)
    end

    return exports.nexa_api['business.listTransactions'](source, payload)
end)
