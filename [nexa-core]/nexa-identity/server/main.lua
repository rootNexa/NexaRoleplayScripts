local RESOURCE = GetCurrentResourceName()
local CHARACTER_RESOURCE = 'nexa-character'
local CORE_RESOURCE = 'nexa-core'
local EVENTS = NexaIdentityEvents

local function log(level, message, context)
    local suffix = ''

    if context ~= nil then
        suffix = (' %s'):format(json.encode(context))
    end

    print(('[%s] [%s] %s%s'):format(RESOURCE, level, message, suffix))
end

local function normalizeSource(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return nil
    end

    return source
end

local function isStarted(resourceName)
    return GetResourceState(resourceName) == 'started'
end

local function callExport(resourceName, exportName, ...)
    if not isStarted(resourceName) then
        return nil, 'RESOURCE_NOT_STARTED'
    end

    local args = { ... }
    local ok, result, err = pcall(function()
        return exports[resourceName][exportName](table.unpack(args))
    end)

    if not ok then
        log('error', 'Export call failed.', {
            resource = resourceName,
            export = exportName,
            error = result
        })
        return nil, 'EXPORT_ERROR'
    end

    return result, err
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
        gender = character.gender
    }
end

local function publicCharacters(characters)
    local public = {}

    for _, character in ipairs(characters or {}) do
        public[#public + 1] = publicCharacter(character)
    end

    return public
end

local function trim(value)
    if type(value) ~= 'string' then
        return nil
    end

    return value:match('^%s*(.-)%s*$')
end

local function validateName(value)
    value = trim(value)

    if not value or value == '' or #value > NexaIdentityConfig.maxNameLength then
        return nil
    end

    if not value:match("^[%a%s%-']+$") then
        return nil
    end

    return value
end

local function validateBirthdate(value)
    value = trim(value)

    if not value or value == '' or not value:match('^%d%d%d%d%-%d%d%-%d%d$') then
        return nil
    end

    local month = tonumber(value:sub(6, 7))
    local day = tonumber(value:sub(9, 10))

    if not month or not day or month < 1 or month > 12 or day < 1 or day > 31 then
        return nil
    end

    return value
end

local function validateGender(value)
    value = trim(value or 'unknown') or 'unknown'

    if not NexaIdentityConfig.allowedGenders[value] then
        return nil
    end

    return value
end

local function validateCreatePayload(data)
    if type(data) ~= 'table' then
        return nil, 'INVALID_INPUT'
    end

    if data.id ~= nil or data.player_id ~= nil or data.playerId ~= nil or data.permission ~= nil or data.permissions ~= nil or data.job ~= nil or data.jobs ~= nil then
        return nil, 'FORBIDDEN_FIELD'
    end

    local firstName = validateName(data.firstName or data.first_name)
    local lastName = validateName(data.lastName or data.last_name)
    local birthdate = validateBirthdate(data.birthdate)
    local gender = validateGender(data.gender)

    if not firstName or not lastName or not birthdate or not gender then
        return nil, 'INVALID_INPUT'
    end

    return {
        first_name = firstName,
        last_name = lastName,
        birthdate = birthdate,
        gender = gender
    }, nil
end

local function sendError(source, code, message)
    TriggerClientEvent(EVENTS.client.error, source, {
        code = code or 'INTERNAL_ERROR',
        message = message or 'Action failed.'
    })
end

local function openFlow(source)
    local characters, err = callExport(CHARACTER_RESOURCE, 'ListCharacters', source)

    if err then
        sendError(source, err, 'Characters could not be loaded.')
        return
    end

    TriggerClientEvent(EVENTS.client.open, source, {
        characters = publicCharacters(characters),
        mode = characters and #characters > 0 and 'select' or 'create'
    })
end

RegisterNetEvent(EVENTS.server.requestFlow, function()
    local source = normalizeSource(source)

    if not source then
        return
    end

    local characters, err = callExport(CHARACTER_RESOURCE, 'ListCharacters', source)

    if err == 'PLAYER_NOT_FOUND' then
        SetTimeout(1500, function()
            if GetPlayerName(source) ~= nil then
                openFlow(source)
            end
        end)
        return
    end

    if err then
        sendError(source, err, 'Characters could not be loaded.')
        return
    end

    TriggerClientEvent(EVENTS.client.open, source, {
        characters = publicCharacters(characters),
        mode = characters and #characters > 0 and 'select' or 'create'
    })
end)

RegisterNetEvent(EVENTS.server.createCharacter, function(data)
    local source = normalizeSource(source)

    if not source then
        return
    end

    local payload, validationError = validateCreatePayload(data)

    if not payload then
        sendError(source, validationError, 'Character data is invalid.')
        return
    end

    local character, createErr = callExport(CHARACTER_RESOURCE, 'CreateCharacter', source, payload)

    if not character then
        sendError(source, createErr, 'Character could not be created.')
        return
    end

    local selected, selectErr = callExport(CHARACTER_RESOURCE, 'SelectCharacter', source, character.id)

    if not selected then
        sendError(source, selectErr, 'Character could not be selected.')
        return
    end

    TriggerClientEvent(EVENTS.client.selected, source, publicCharacter(selected))
end)

RegisterNetEvent(EVENTS.server.selectCharacter, function(characterId)
    local source = normalizeSource(source)

    if not source then
        return
    end

    characterId = tonumber(characterId)

    if not characterId or characterId <= 0 then
        sendError(source, 'INVALID_INPUT', 'Character selection is invalid.')
        return
    end

    local selected, selectErr = callExport(CHARACTER_RESOURCE, 'SelectCharacter', source, characterId)

    if not selected then
        sendError(source, selectErr, 'Character could not be selected.')
        return
    end

    TriggerClientEvent(EVENTS.client.selected, source, publicCharacter(selected))
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    log('info', 'nexa-identity started.', {
        core = GetResourceState(CORE_RESOURCE),
        character = GetResourceState(CHARACTER_RESOURCE)
    })
end)
