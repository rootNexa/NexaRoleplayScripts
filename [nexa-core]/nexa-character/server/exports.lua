local errorMessages = {
    INVALID_INPUT = 'Character input is invalid.',
    INVALID_SOURCE = 'Player source is invalid.',
    FORBIDDEN_FIELD = 'Character input contains forbidden fields.',
    PLAYER_NOT_FOUND = 'Player session was not found.',
    CHARACTER_LIMIT_REACHED = 'Character limit reached.',
    DATABASE_ERROR = 'Character data could not be saved.',
    NOT_FOUND = 'Character was not found.',
    CORE_UNAVAILABLE = 'Core export is unavailable.'
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

function ListCharacters(source)
    local data, err = NexaCharacter.ListCharacters(source)
    return exportResponse(data or {}, err, {
        source = tonumber(source)
    })
end

function CreateCharacter(source, data)
    local character, err = NexaCharacter.CreateCharacter(source, data)
    return exportResponse(character, err)
end

function SelectCharacter(source, characterId)
    local character, err = NexaCharacter.SelectCharacter(source, characterId)
    return exportResponse(character, err)
end

function GetActiveCharacter(source)
    local character, err = NexaCharacter.GetActiveCharacter(source)
    return exportResponse(character, err)
end

function UpdateCharacter(source, data)
    local character, err = NexaCharacter.UpdateCharacter(source, data)
    return exportResponse(character, err)
end
