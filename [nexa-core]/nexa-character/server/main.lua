NexaCharacter = NexaCharacter or {}
NexaCharacter.activeBySource = NexaCharacter.activeBySource or {}

local CORE_RESOURCE = 'nexa-core'
local EVENTS = NEXA_CHARACTER_CONSTANTS.events

local function log(level, message, context)
    local suffix = ''

    if context ~= nil then
        suffix = (' %s'):format(json.encode(context))
    end

    print(('[%s] [%s] %s%s'):format(NEXA_CHARACTER_CONSTANTS.resourceName, level, message, suffix))
end

local function response(success, code, message, data, details)
    return {
        success = success == true,
        code = code,
        message = message,
        data = data,
        details = details
    }
end

local function ok(data, message)
    return response(true, 'OK', message or 'OK', data, nil)
end

local function fail(code, message, details)
    return response(false, code or 'INTERNAL_ERROR', message or 'Der Vorgang konnte nicht abgeschlossen werden.', nil, details)
end

local function normalizeSource(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return nil
    end

    return source
end

local function isCoreStarted()
    return GetResourceState(CORE_RESOURCE) == 'started'
end

local function callCore(name, ...)
    if not isCoreStarted() then
        return nil, 'CORE_UNAVAILABLE'
    end

    local args = { ... }
    local okCall, result, err = pcall(function()
        return exports[CORE_RESOURCE][name](table.unpack(args))
    end)

    if not okCall then
        log('error', 'Core export call failed.', {
            export = name,
            error = result
        })
        return nil, 'CORE_UNAVAILABLE'
    end

    return result, err
end

local function emit(source, eventName, payload)
    TriggerClientEvent(eventName, source, payload)
end

local function publicCharacter(character)
    if type(character) ~= 'table' then
        return nil
    end

    return {
        id = character.id,
        firstName = character.firstName,
        lastName = character.lastName,
        birthdate = character.birthdate,
        gender = character.gender,
        metadata = type(character.metadata) == 'table' and character.metadata or {},
        createdAt = character.createdAt,
        updatedAt = character.updatedAt
    }
end

local function publicCharacters(characters)
    local public = {}

    for _, character in ipairs(characters or {}) do
        public[#public + 1] = publicCharacter(character)
    end

    return public
end

function NexaCharacter.ListCharacters(source)
    source = normalizeSource(source)

    if not source then
        return nil, 'INVALID_INPUT'
    end

    return callCore('ListCharacters', source)
end

function NexaCharacter.CreateCharacter(source, data)
    source = normalizeSource(source)

    if not source then
        return nil, 'INVALID_INPUT'
    end

    local payload, validationError, detail = NexaCharacter.Validation.ValidateCreate(data)

    if not payload then
        log('warn', 'Character create validation failed.', {
            source = source,
            error = validationError,
            detail = detail
        })
        return nil, validationError
    end

    return callCore('CreateCharacter', source, payload)
end

function NexaCharacter.SelectCharacter(source, characterId)
    source = normalizeSource(source)

    if not source then
        return nil, 'INVALID_INPUT'
    end

    characterId = NexaCharacter.Validation.ValidateSelect(characterId)

    if not characterId then
        return nil, 'INVALID_INPUT'
    end

    local character, err = callCore('SelectCharacter', source, characterId)

    if character then
        NexaCharacter.activeBySource[source] = character
    end

    return character, err
end

function NexaCharacter.GetActiveCharacter(source)
    source = normalizeSource(source)

    if not source then
        return nil, 'INVALID_INPUT'
    end

    local character, err = callCore('GetCharacter', source)

    if character then
        NexaCharacter.activeBySource[source] = character
    end

    return character, err
end

function NexaCharacter.UpdateCharacter(source, data)
    source = normalizeSource(source)

    if not source then
        return nil, 'INVALID_INPUT'
    end

    local payload, validationError = NexaCharacter.Validation.ValidateUpdate(data)

    if not payload then
        return nil, validationError
    end

    local character, err = callCore('UpdateCharacter', source, payload)

    if character then
        NexaCharacter.activeBySource[source] = character
    end

    return character, err
end

RegisterNetEvent(EVENTS.server.list, function()
    local source = normalizeSource(source)

    if not source then
        return
    end

    local characters, err = NexaCharacter.ListCharacters(source)

    emit(source, EVENTS.client.charactersLoaded, characters and ok(publicCharacters(characters), 'Characters loaded.') or fail(err, 'Characters could not be loaded.'))
end)

RegisterNetEvent(EVENTS.server.create, function(data)
    local source = normalizeSource(source)

    if not source then
        return
    end

    local character, err = NexaCharacter.CreateCharacter(source, data)

    if not character then
        emit(source, EVENTS.client.charactersLoaded, fail(err, 'Character could not be created.'))
        return
    end

    local characters, listErr = NexaCharacter.ListCharacters(source)

    emit(source, EVENTS.client.charactersLoaded, characters and ok(publicCharacters(characters), 'Character created.') or fail(listErr, 'Characters could not be loaded.'))
end)

RegisterNetEvent(EVENTS.server.select, function(characterId)
    local source = normalizeSource(source)

    if not source then
        return
    end

    local character, err = NexaCharacter.SelectCharacter(source, characterId)

    emit(source, EVENTS.client.characterSelected, character and ok(publicCharacter(character), 'Character selected.') or fail(err, 'Character could not be selected.'))
end)

RegisterNetEvent(EVENTS.server.update, function(data)
    local source = normalizeSource(source)

    if not source then
        return
    end

    local character, err = NexaCharacter.UpdateCharacter(source, data)

    emit(source, EVENTS.client.characterUpdated, character and ok(publicCharacter(character), 'Character updated.') or fail(err, 'Character could not be updated.'))
end)

AddEventHandler('playerDropped', function()
    local source = normalizeSource(source)

    if source then
        NexaCharacter.activeBySource[source] = nil
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    local core = callCore('GetCoreObject')

    log(core and 'info' or 'error', core and 'nexa-character started.' or 'nexa-character started without core export access.', {
        core = core and '<present>' or nil
    })
end)
