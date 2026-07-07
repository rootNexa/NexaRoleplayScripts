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

local function debugLog(message, metadata)
    if GetConvar('nexa:identityDebug', 'false') ~= 'true' then
        return
    end

    print(('[nexa_identity:server] %s %s'):format(message, metadata and json.encode(metadata) or ''))
end

local function getPayloadFieldTypes(payload)
    if type(payload) ~= 'table' then
        return {
            payload = type(payload)
        }
    end

    local fieldTypes = {}

    for key, value in pairs(payload) do
        fieldTypes[key] = type(value)
    end

    return fieldTypes
end

lib.callback.register('nexa:identity:cb:listCharacters', function(source)
    local rejected = checkRequest(source, 'nexa:identity:cb:listCharacters')

    if rejected ~= nil then
        debugLog('listCharacters callback rejected', {
            source = source,
            code = rejected.code
        })
        return rejected
    end

    local response = exports.nexa_api:listCharacters(source)
    debugLog('4 Servercallback erfolgreich: listCharacters', {
        source = source,
        success = response and response.success or false,
        count = response and response.data and response.data.characters and #response.data.characters or nil
    })
    return response
end)

lib.callback.register('nexa:identity:cb:createCharacter', function(source, payload)
    debugLog('createCharacter payload received', {
        source = source,
        payload = payload,
        fieldTypes = getPayloadFieldTypes(payload),
        expected = {
            firstname = 'string length 2-32, letters/spaces/hyphen/apostrophe',
            lastname = 'string length 2-32, letters/spaces/hyphen/apostrophe',
            birthdate = 'YYYY-MM-DD string',
            gender = 'male, female, or diverse',
            nationality = 'optional string max 64'
        }
    })

    local rejected = checkRequest(source, 'nexa:identity:cb:createCharacter')

    if rejected ~= nil then
        debugLog('createCharacter callback rejected', {
            source = source,
            code = rejected.code
        })
        return rejected
    end

    local valid, code, validation = validateCharacterPayload(payload)

    if not valid then
        debugLog('createCharacter callback rejected by validation', {
            source = source,
            code = code,
            validation = validation
        })
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Charakterdaten.', nil, nil, nil)
    end

    debugLog('2 Charakter erstellt: callback accepted', {
        source = source
    })
    local response = exports.nexa_api:createCharacter(source, payload)
    debugLog('3 Charakter gespeichert', {
        source = source,
        success = response and response.success or false,
        characterId = response and response.data and response.data.character and response.data.character.id or nil
    })
    debugLog('4 Servercallback erfolgreich: createCharacter', {
        source = source,
        success = response and response.success or false,
        code = response and response.code or nil
    })
    return response
end)

lib.callback.register('nexa:identity:cb:selectCharacter', function(source, characterId)
    local rejected = checkRequest(source, 'nexa:identity:cb:selectCharacter')

    if rejected ~= nil then
        debugLog('selectCharacter callback rejected', {
            source = source,
            code = rejected.code
        })
        return rejected
    end

    local valid, code = validateCharacterId(characterId)

    if not valid then
        debugLog('selectCharacter callback rejected by validation', {
            source = source,
            code = code,
            characterId = characterId
        })
        return exports.nexa_api:buildResponse(false, code, 'Ungueltiger Charakter.', nil, nil, nil)
    end

    debugLog('5 Character Selected Event: callback accepted', {
        source = source,
        characterId = characterId
    })
    local response = exports.nexa_api:selectCharacter(source, characterId)
    debugLog('4 Servercallback erfolgreich: selectCharacter', {
        source = source,
        success = response and response.success or false,
        code = response and response.code or nil,
        characterId = characterId
    })
    return response
end)

lib.callback.register('nexa:identity:cb:deleteCharacter', function(source, characterId)
    local rejected = checkRequest(source, 'nexa:identity:cb:deleteCharacter')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateCharacterId(characterId)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltiger Charakter.', nil, nil, nil)
    end

    return exports.nexa_api:deleteCharacter(source, characterId)
end)

lib.callback.register('nexa:identity:cb:getActiveCharacter', function(source)
    local rejected = checkRequest(source, 'nexa:identity:cb:getActiveCharacter')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_api:getActiveCharacter(source)
end)
