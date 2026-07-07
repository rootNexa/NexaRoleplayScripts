local function notify(source, response)
    TriggerClientEvent('nexa:identity:client:requestResult', source, response)
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

RegisterNetEvent(NEXA_IDENTITY_EVENTS.requestOpenManager, function()
    local source = source

    if not isAllowed(source, NEXA_IDENTITY_EVENTS.requestOpenManager) then
        return
    end

    TriggerClientEvent(NEXA_IDENTITY_EVENTS.openManager, source)
end)

RegisterNetEvent(NEXA_IDENTITY_EVENTS.requestCreateCharacter, function(payload)
    local source = source

    if not isAllowed(source, NEXA_IDENTITY_EVENTS.requestCreateCharacter) then
        return
    end

    local valid, code = validateCharacterPayload(payload)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltige Charakterdaten.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api:createCharacter(source, payload))
end)

RegisterNetEvent(NEXA_IDENTITY_EVENTS.requestSelectCharacter, function(characterId)
    local source = source

    if not isAllowed(source, NEXA_IDENTITY_EVENTS.requestSelectCharacter) then
        return
    end

    local valid, code = validateCharacterId(characterId)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltiger Charakter.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api:selectCharacter(source, characterId))
end)

RegisterNetEvent(NEXA_IDENTITY_EVENTS.requestDeleteCharacter, function(characterId)
    local source = source

    if not isAllowed(source, NEXA_IDENTITY_EVENTS.requestDeleteCharacter) then
        return
    end

    local valid, code = validateCharacterId(characterId)

    if not valid then
        notify(source, exports.nexa_api:buildResponse(false, code, 'Ungueltiger Charakter.', nil, nil, nil))
        return
    end

    notify(source, exports.nexa_api:deleteCharacter(source, characterId))
end)
