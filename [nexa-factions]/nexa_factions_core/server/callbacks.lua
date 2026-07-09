local function featureEnabled()
    if GetResourceState('nexa_featureflags') ~= 'started' then
        return true
    end

    return exports.nexa_featureflags:isEnabled(NexaFactionsConfig.featureFlag)
end

local function checkRequest(source, eventName)
    if not featureEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Fraktions-Core ist derzeit deaktiviert.', nil, nil, nil)
    end

    if not exports.nexa_security:validateSource(source) then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return exports.nexa_api:buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil)
    end

    return nil
end

exports.nexa_api:RegisterServerCallback('nexa:factions_core:cb:getOverview', function(source, payload)
    local rejected = checkRequest(source, 'nexa:factions_core:cb:getOverview')

    if rejected ~= nil then
        return rejected
    end

    if not validateFactionReferencePayload(payload, true) then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Fraktionsdaten.', nil, nil, nil)
    end

    return exports.nexa_api['faction.getCurrent'](source, payload or {})
end)

exports.nexa_api:RegisterServerCallback('nexa:factions_core:cb:listMembers', function(source, payload)
    local rejected = checkRequest(source, 'nexa:factions_core:cb:listMembers')

    if rejected ~= nil then
        return rejected
    end

    if not validateFactionReferencePayload(payload, true) then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Fraktionsdaten.', nil, nil, nil)
    end

    return exports.nexa_api['faction.listMembers'](source, payload or {})
end)

exports.nexa_api:RegisterServerCallback('nexa:factions_core:cb:listAccounts', function(source, payload)
    local rejected = checkRequest(source, 'nexa:factions_core:cb:listAccounts')

    if rejected ~= nil then
        return rejected
    end

    if not validateFactionReferencePayload(payload, true) then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Fraktionsdaten.', nil, nil, nil)
    end

    return exports.nexa_api['faction.listAccounts'](source, payload or {})
end)

exports.nexa_api:RegisterServerCallback('nexa:factions_core:cb:setCallsign', function(source, payload)
    local rejected = checkRequest(source, 'nexa:factions_core:cb:setCallsign')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateCallsignPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Callsign-Daten.', nil, nil, nil)
    end

    return exports.nexa_api['faction.setCallsign'](source, payload)
end)

exports.nexa_api:RegisterServerCallback('nexa:factions_core:cb:assignMember', function(source, payload)
    local rejected = checkRequest(source, 'nexa:factions_core:cb:assignMember')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateAssignMemberPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Mitgliedsdaten.', nil, nil, nil)
    end

    return exports.nexa_api['faction.assignMember'](source, payload)
end)

exports.nexa_api:RegisterServerCallback('nexa:factions_core:cb:transferFunds', function(source, payload)
    local rejected = checkRequest(source, 'nexa:factions_core:cb:transferFunds')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateFactionTransferPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Kontodaten.', nil, nil, nil)
    end

    return exports.nexa_api['faction.transferFunds'](source, payload)
end)
