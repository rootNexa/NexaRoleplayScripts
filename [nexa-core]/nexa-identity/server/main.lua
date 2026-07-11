local RESOURCE = GetCurrentResourceName()
local CHARACTER_RESOURCE = 'nexa-character'
local PLAYERSTATE_RESOURCE = 'nexa_playerstate'
local CORE_RESOURCE = 'nexa-core'
local EVENTS = NexaIdentityEvents
local pendingSpawnBySource = {}
local sendError
local SPAWN_REQUEST_TIMEOUT_MS = 20000

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
        local resourceExports = exports[resourceName]
        return resourceExports[exportName](resourceExports, table.unpack(args))
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

local errorMessages = {
    INVALID_INPUT = 'Character input is invalid.',
    FORBIDDEN_FIELD = 'Character input contains forbidden fields.',
    PLAYER_NOT_FOUND = 'Player session was not found.',
    CHARACTER_LIMIT_REACHED = 'Character limit reached.',
    DATABASE_ERROR = 'Character data could not be saved.',
    NOT_FOUND = 'Character was not found.',
    RESOURCE_NOT_STARTED = 'Required resource is not started.',
    EXPORT_ERROR = 'Export call failed.',
    SPAWN_ALREADY_PENDING = 'Spawn request is already pending.',
    SPAWN_REJECTED = 'Spawn request was rejected.',
    PLAYER_DISCONNECTED = 'Player disconnected before spawn could start.'
}

local function normalizeExportResult(action, result, err)
    if type(result) == 'table' and type(result.ok) == 'boolean' then
        if result.ok then
            return {
                ok = true,
                data = result.data,
                error = nil,
                raw = result
            }
        end

        local errorPayload = type(result.error) == 'table' and result.error or {}

        return {
            ok = false,
            data = nil,
            error = {
                code = errorPayload.code or err or 'UNKNOWN_ERROR',
                message = errorPayload.message or errorMessages[errorPayload.code] or 'Character operation failed.',
                details = errorPayload.details
            },
            raw = result
        }
    end

    if err ~= nil or result == nil then
        return {
            ok = false,
            data = nil,
            error = {
                code = err or 'UNKNOWN_ERROR',
                message = errorMessages[err] or 'Character operation failed.',
                details = {
                    action = action,
                    resultType = type(result)
                }
            },
            raw = {
                result = result,
                err = err
            }
        }
    end

    log('warn', 'Unexpected character export response format; normalized as success.', {
        action = action,
        resultType = type(result)
    })

    return {
        ok = true,
        data = result,
        error = nil,
        raw = {
            result = result,
            err = err
        }
    }
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

local function responseErrorCode(response)
    if type(response) ~= 'table' then
        return nil
    end

    if type(response.error) == 'table' and response.error.code then
        return response.error.code
    end

    return response.code
end

local function responseErrorMessage(response)
    if type(response) ~= 'table' then
        return nil
    end

    if type(response.error) == 'table' and response.error.message then
        return response.error.message
    end

    return response.message
end

local function verifyActiveCharacter(source, characterId)
    local activeResult, activeErr = callExport(CHARACTER_RESOURCE, 'GetActiveCharacter', source)
    local activeResponse = normalizeExportResult('GetActiveCharacter', activeResult, activeErr)

    if not activeResponse.ok or type(activeResponse.data) ~= 'table' or tonumber(activeResponse.data.id) ~= tonumber(characterId) then
        return false, {
            code = activeResponse.error and activeResponse.error.code or 'NOT_FOUND',
            message = 'Selected character is not active.',
            details = activeResponse.error
        }
    end

    return true, activeResponse.data
end

local function requestPlayerSpawn(source, character)
    if GetPlayerName(source) == nil then
        return false, {
            code = 'PLAYER_DISCONNECTED',
            message = errorMessages.PLAYER_DISCONNECTED
        }
    end

    if type(character) ~= 'table' or tonumber(character.id) == nil then
        return false, {
            code = 'NOT_FOUND',
            message = 'Selected character is not active.'
        }
    end

    local active, activeResult = verifyActiveCharacter(source, character.id)

    if not active then
        return false, activeResult
    end

    if pendingSpawnBySource[source] then
        return false, {
            code = 'SPAWN_ALREADY_PENDING',
            message = errorMessages.SPAWN_ALREADY_PENDING
        }
    end

    if not isStarted(PLAYERSTATE_RESOURCE) then
        return false, {
            code = 'RESOURCE_NOT_STARTED',
            message = 'PlayerState is not started.'
        }
    end

    pendingSpawnBySource[source] = {
        characterId = tonumber(character.id),
        requestedAt = os.time()
    }

    local okCall, spawnResponse = pcall(function()
        return exports[PLAYERSTATE_RESOURCE]:RequestSpawn(source)
    end)

    if not okCall then
        pendingSpawnBySource[source] = nil
        log('error', 'PlayerState RequestSpawn export failed.', {
            source = source,
            characterId = character.id,
            error = spawnResponse
        })
        return false, {
            code = 'EXPORT_ERROR',
            message = errorMessages.EXPORT_ERROR
        }
    end

    local accepted = type(spawnResponse) == 'table' and (spawnResponse.ok == true or spawnResponse.success == true)

    if not accepted then
        pendingSpawnBySource[source] = nil
        return false, {
            code = responseErrorCode(spawnResponse) or 'SPAWN_REJECTED',
            message = responseErrorMessage(spawnResponse) or errorMessages.SPAWN_REJECTED,
            details = spawnResponse
        }
    end

    log('info', 'PlayerState spawn request accepted.', {
        source = source,
        characterId = character.id,
        response = spawnResponse
    })

    SetTimeout(SPAWN_REQUEST_TIMEOUT_MS, function()
        local pending = pendingSpawnBySource[source]

        if pending and pending.characterId == tonumber(character.id) then
            pendingSpawnBySource[source] = nil
            log('warn', 'PlayerState spawn request timed out before gameplay ready.', {
                source = source,
                characterId = character.id
            })
        end
    end)

    return true, spawnResponse
end

local function completeCharacterSelection(source, character)
    local spawnStarted, spawnResult = requestPlayerSpawn(source, character)

    if not spawnStarted then
        log('warn', 'Character selected but spawn request failed.', {
            source = source,
            characterId = character and character.id or nil,
            error = spawnResult
        })
        sendError(source, spawnResult.code, spawnResult.message, spawnResult.details)
        return false
    end

    TriggerClientEvent(EVENTS.client.selected, source, publicCharacter(character))
    return true
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
    local height = tonumber(data.height)
    local weight = tonumber(data.weight)

    if not firstName
        or not lastName
        or not birthdate
        or not gender
        or not height
        or not weight
    then
        return nil, 'INVALID_INPUT'
    end

    return {
        first_name = firstName,
        last_name = lastName,
        birthdate = birthdate,
        gender = gender,
        height = math.floor(height),
        weight = math.floor(weight)
    }, nil
end

sendError = function(source, code, message, details)
    TriggerClientEvent(EVENTS.client.error, source, {
        code = code or 'INTERNAL_ERROR',
        message = message or errorMessages[code] or 'Action failed.',
        details = details
    })
end

local function openFlow(source)
    local result, err = callExport(CHARACTER_RESOURCE, 'ListCharacters', source)
    local normalized = normalizeExportResult('ListCharacters', result, err)

    if not normalized.ok then
        log('warn', 'ListCharacters failed.', {
            source = source,
            error = normalized.error,
            raw = normalized.raw
        })
        sendError(source, normalized.error.code, normalized.error.message, normalized.error.details)
        return
    end

    TriggerClientEvent(EVENTS.client.open, source, {
        characters = publicCharacters(normalized.data),
        mode = normalized.data and #normalized.data > 0 and 'select' or 'create'
    })
end

RegisterNetEvent(EVENTS.server.requestFlow, function()
    local source = normalizeSource(source)

    if not source then
        return
    end

    log('info', 'Identity flow requested.', {
        source = source,
        action = 'ListCharacters'
    })

    local result, err = callExport(CHARACTER_RESOURCE, 'ListCharacters', source)
    local normalized = normalizeExportResult('ListCharacters', result, err)

    log(normalized.ok and 'info' or 'warn', 'ListCharacters export result for identity flow.', {
        source = source,
        response = normalized.raw,
        normalized = {
            ok = normalized.ok,
            error = normalized.error,
            count = type(normalized.data) == 'table' and #normalized.data or nil
        }
    })

    if normalized.error and normalized.error.code == 'PLAYER_NOT_FOUND' then
        SetTimeout(1500, function()
            if GetPlayerName(source) ~= nil then
                openFlow(source)
            end
        end)
        return
    end

    if not normalized.ok then
        log('warn', 'Identity flow request failed.', {
            source = source,
            error = normalized.error,
            raw = normalized.raw
        })
        sendError(source, normalized.error.code, normalized.error.message, normalized.error.details)
        return
    end

    TriggerClientEvent(EVENTS.client.open, source, {
        characters = publicCharacters(normalized.data),
        mode = normalized.data and #normalized.data > 0 and 'select' or 'create'
    })
end)

RegisterNetEvent(EVENTS.server.createCharacter, function(data)
    local source = normalizeSource(source)

    if not source then
        return
    end

    log('debug', 'CreateCharacter request received.', {
        source = source,
        firstNameLength = type(data) == 'table' and type(data.firstName or data.first_name) == 'string' and #(data.firstName or data.first_name) or nil,
        lastNameLength = type(data) == 'table' and type(data.lastName or data.last_name) == 'string' and #(data.lastName or data.last_name) or nil,
        birthdateProvided = type(data) == 'table' and data.birthdate ~= nil or false,
        gender = type(data) == 'table' and data.gender or nil
    })

    local payload, validationError = validateCreatePayload(data)

    if not payload then
        log('warn', 'CreateCharacter validation failed.', {
            source = source,
            code = validationError
        })
        sendError(source, validationError, errorMessages[validationError] or 'Character data is invalid.')
        return
    end

    log('debug', 'CreateCharacter normalized payload.', {
        source = source,
        height = payload and payload.height or nil,
        heightType = payload and type(payload.height) or nil,
        weight = payload and payload.weight or nil,
        weightType = payload and type(payload.weight) or nil
    })

    local createResult, createErr = callExport(CHARACTER_RESOURCE, 'CreateCharacter', source, payload)
    local createResponse = normalizeExportResult('CreateCharacter', createResult, createErr)

    log(createResponse.ok and 'info' or 'warn', 'CreateCharacter export result.', {
        source = source,
        response = createResponse.raw,
        normalized = {
            ok = createResponse.ok,
            error = createResponse.error
        }
    })

    if not createResponse.ok then
        sendError(source, createResponse.error.code, createResponse.error.message, createResponse.error.details)
        return
    end

    local character = createResponse.data
    local selectResult, selectErr = callExport(CHARACTER_RESOURCE, 'SelectCharacter', source, character and character.id)
    local selectResponse = normalizeExportResult('SelectCharacter', selectResult, selectErr)

    log(selectResponse.ok and 'info' or 'warn', 'SelectCharacter after create result.', {
        source = source,
        response = selectResponse.raw,
        normalized = {
            ok = selectResponse.ok,
            error = selectResponse.error
        }
    })

    if not selectResponse.ok then
        sendError(source, selectResponse.error.code, selectResponse.error.message, selectResponse.error.details)
        return
    end

    completeCharacterSelection(source, selectResponse.data)
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

    local selectedResult, selectErr = callExport(CHARACTER_RESOURCE, 'SelectCharacter', source, characterId)
    local selectResponse = normalizeExportResult('SelectCharacter', selectedResult, selectErr)

    log(selectResponse.ok and 'info' or 'warn', 'SelectCharacter export result.', {
        source = source,
        characterId = characterId,
        response = selectResponse.raw,
        normalized = {
            ok = selectResponse.ok,
            error = selectResponse.error
        }
    })

    if not selectResponse.ok then
        sendError(source, selectResponse.error.code, selectResponse.error.message, selectResponse.error.details)
        return
    end

    completeCharacterSelection(source, selectResponse.data)
end)

AddEventHandler('nexa:playerstate:active', function(payload)
    local playerSource = payload and normalizeSource(payload.source)

    if playerSource then
        pendingSpawnBySource[playerSource] = nil
    end
end)

AddEventHandler('nexa:player:ready', function(payload)
    local playerSource = payload and normalizeSource(payload.source)

    if playerSource then
        pendingSpawnBySource[playerSource] = nil
    end
end)

AddEventHandler('nexa:playerstate:failed', function(payload)
    local playerSource = payload and normalizeSource(payload.source)

    if playerSource then
        pendingSpawnBySource[playerSource] = nil
    end
end)

AddEventHandler('playerDropped', function()
    local source = normalizeSource(source)

    if source then
        pendingSpawnBySource[source] = nil
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == RESOURCE then
        pendingSpawnBySource = {}
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    log('info', 'nexa-identity started.', {
        core = GetResourceState(CORE_RESOURCE),
        character = GetResourceState(CHARACTER_RESOURCE),
        playerstate = GetResourceState(PLAYERSTATE_RESOURCE)
    })
end)
