local errorMessages = {
    INVALID_INPUT = 'Character input is invalid.',
    INVALID_SOURCE = 'Player source is invalid.',
    FORBIDDEN_FIELD = 'Character input contains forbidden fields.',
    PLAYER_NOT_FOUND = 'Player session was not found.',
    CHARACTER_LIMIT_REACHED = 'Character limit reached.',
    DATABASE_ERROR = 'Character data could not be saved.',
    NOT_FOUND = 'Character was not found.',
    CORE_UNAVAILABLE = 'Core export is unavailable.',
    CHARACTER_DOMAIN_UNAVAILABLE = 'Character domain is unavailable.'
}

local function exportResponse(data, err, details)
    if err then
        return {
            ok = false,
            data = nil,
            error = {
                code = err,
                message = errorMessages[err] or 'Character operation failed.',
                details = details
            }
        }
    end

    return {
        ok = true,
        data = data,
        error = nil
    }
end

local function sourceDebug(value)
    return {
        value = value,
        valueType = type(value),
        tonumberValue = tonumber(value)
    }
end

local function logExportEntry(name, source)
    local suffix = (' %s'):format(json.encode({
        export = name,
        source = sourceDebug(source)
    }))

    print(('[nexa-character] [info] Export entry.%s'):format(suffix))
end

function ListCharacters(source)
    logExportEntry('ListCharacters', source)
    local data, err = NexaCharacter.ListCharacters(source)
    return exportResponse(data or {}, err, {
        source = tonumber(source)
    })
end

function CreateCharacter(source, data)
    logExportEntry('CreateCharacter', source)
    local character, err = NexaCharacter.CreateCharacter(source, data)
    return exportResponse(character, err)
end

function SelectCharacter(source, characterId)
    logExportEntry('SelectCharacter', source)
    local character, err = NexaCharacter.SelectCharacter(source, characterId)
    return exportResponse(character, err)
end

function GetActiveCharacter(source)
    logExportEntry('GetActiveCharacter', source)
    local character, err = NexaCharacter.GetActiveCharacter(source)
    return exportResponse(character, err)
end

function UpdateCharacter(source, data)
    logExportEntry('UpdateCharacter', source)
    local character, err = NexaCharacter.UpdateCharacter(source, data)
    return exportResponse(character, err)
end
