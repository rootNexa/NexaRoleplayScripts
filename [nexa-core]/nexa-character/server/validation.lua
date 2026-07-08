NexaCharacter = NexaCharacter or {}
NexaCharacter.Validation = {}

local forbiddenKeys = {
    id = true,
    player_id = true,
    playerId = true,
    permission = true,
    permissions = true,
    job = true,
    jobs = true,
    group = true,
    groups = true
}

local function trim(value)
    if type(value) ~= 'string' then
        return nil
    end

    return value:match('^%s*(.-)%s*$')
end

local function validateName(value, maxLength)
    value = trim(value)

    if not value or value == '' or #value > maxLength then
        return nil
    end

    if not value:match("^[%a%s%-']+$") then
        return nil
    end

    return value
end

local function validateBirthdate(value)
    value = trim(value)

    if not value or value == '' then
        return NexaCharacterConfig.defaultBirthdate
    end

    if not value:match('^%d%d%d%d%-%d%d%-%d%d$') then
        return nil
    end

    local year = tonumber(value:sub(1, 4))
    local month = tonumber(value:sub(6, 7))
    local day = tonumber(value:sub(9, 10))

    if not year or not month or not day or month < 1 or month > 12 or day < 1 or day > 31 then
        return nil
    end

    return value
end

local function validateGender(value)
    value = trim(value or 'unknown') or 'unknown'

    if #value > NexaCharacterConfig.maxGenderLength or not NexaCharacterConfig.allowedGenders[value] then
        return nil
    end

    return value
end

local function hasForbiddenKeys(data)
    for key in pairs(forbiddenKeys) do
        if data[key] ~= nil then
            return true, key
        end
    end

    return false, nil
end

function NexaCharacter.Validation.ValidateCreate(data)
    if type(data) ~= 'table' then
        return nil, 'INVALID_INPUT'
    end

    local hasForbidden, key = hasForbiddenKeys(data)

    if hasForbidden then
        return nil, 'FORBIDDEN_FIELD', key
    end

    local firstName = validateName(data.first_name or data.firstName, NexaCharacterConfig.maxFirstNameLength)
    local lastName = validateName(data.last_name or data.lastName, NexaCharacterConfig.maxLastNameLength)
    local birthdate = validateBirthdate(data.birthdate)
    local gender = validateGender(data.gender)

    if not firstName or not lastName or not birthdate or not gender then
        return nil, 'INVALID_INPUT'
    end

    return {
        firstName = firstName,
        lastName = lastName,
        birthdate = birthdate,
        gender = gender
    }, nil
end

function NexaCharacter.Validation.ValidateSelect(characterId)
    characterId = tonumber(characterId)

    if not characterId or characterId <= 0 then
        return nil, 'INVALID_INPUT'
    end

    return characterId, nil
end

function NexaCharacter.Validation.ValidateUpdate(data)
    if type(data) ~= 'table' then
        return nil, 'INVALID_INPUT'
    end

    if data.id ~= nil or data.player_id ~= nil or data.playerId ~= nil or data.permission ~= nil or data.permissions ~= nil or data.job ~= nil or data.jobs ~= nil or data.group ~= nil or data.groups ~= nil then
        return nil, 'FORBIDDEN_FIELD'
    end

    local characterId = tonumber(data.character_id or data.characterId)

    if not characterId or characterId <= 0 then
        return nil, 'INVALID_INPUT'
    end

    local payload = {
        characterId = characterId
    }
    local hasChanges = false

    if data.first_name ~= nil or data.firstName ~= nil then
        local firstName = validateName(data.first_name or data.firstName, NexaCharacterConfig.maxFirstNameLength)

        if not firstName then
            return nil, 'INVALID_INPUT'
        end

        payload.firstName = firstName
        hasChanges = true
    end

    if data.last_name ~= nil or data.lastName ~= nil then
        local lastName = validateName(data.last_name or data.lastName, NexaCharacterConfig.maxLastNameLength)

        if not lastName then
            return nil, 'INVALID_INPUT'
        end

        payload.lastName = lastName
        hasChanges = true
    end

    if data.birthdate ~= nil then
        local birthdate = validateBirthdate(data.birthdate)

        if not birthdate then
            return nil, 'INVALID_INPUT'
        end

        payload.birthdate = birthdate
        hasChanges = true
    end

    if data.gender ~= nil then
        local gender = validateGender(data.gender)

        if not gender then
            return nil, 'INVALID_INPUT'
        end

        payload.gender = gender
        hasChanges = true
    end

    if not hasChanges then
        return nil, 'INVALID_INPUT'
    end

    return payload, nil
end
