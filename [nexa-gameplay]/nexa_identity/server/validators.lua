local function normalizeText(value)
    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return nil
    end

    return trimmed
end

local function validationError(field, reason, expected, value)
    return {
        field = field,
        reason = reason,
        expected = expected,
        value = value,
        valueType = type(value)
    }
end

local function isNameValid(field, value)
    local normalized = normalizeText(value)

    if normalized == nil then
        return false, validationError(field, 'missing_or_blank', ('string length %d-%d matching letters/spaces/hyphen/apostrophe'):format(NexaIdentityConfig.minNameLength, NexaIdentityConfig.maxNameLength), value)
    end

    if #normalized < NexaIdentityConfig.minNameLength or #normalized > NexaIdentityConfig.maxNameLength then
        return false, validationError(field, 'length', ('%d-%d characters'):format(NexaIdentityConfig.minNameLength, NexaIdentityConfig.maxNameLength), value)
    end

    if normalized:find('[^%a%s%-\']') ~= nil then
        return false, validationError(field, 'pattern', "letters/spaces/hyphen/apostrophe only", value)
    end

    return true
end

local function getCreateCharacterValidationError(payload)
    if type(payload) ~= 'table' then
        return validationError('payload', 'type', 'table', payload)
    end

    local firstValid, firstError = isNameValid('firstname', payload.firstname)

    if not firstValid then
        return firstError
    end

    local lastValid, lastError = isNameValid('lastname', payload.lastname)

    if not lastValid then
        return lastError
    end

    if type(payload.birthdate) ~= 'string' then
        return validationError('birthdate', 'type', 'YYYY-MM-DD string', payload.birthdate)
    end

    if not payload.birthdate:match('^%d%d%d%d%-%d%d%-%d%d$') then
        return validationError('birthdate', 'format', 'YYYY-MM-DD', payload.birthdate)
    end

    local gender = normalizeText(payload.gender)

    if gender == nil then
        return validationError('gender', 'missing_or_blank', 'male, female, or diverse', payload.gender)
    end

    if NexaIdentityConfig.allowedGenders[gender:lower()] == nil then
        return validationError('gender', 'enum', 'male, female, or diverse', payload.gender)
    end

    return nil
end

function validateCharacterPayload(payload)
    local error = getCreateCharacterValidationError(payload)

    if error ~= nil then
        return false, 'INVALID_INPUT', error
    end

    return true, 'OK'
end

function validateCharacterId(characterId)
    local normalizedCharacterId = tonumber(characterId)

    if normalizedCharacterId == nil or normalizedCharacterId <= 0 then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
