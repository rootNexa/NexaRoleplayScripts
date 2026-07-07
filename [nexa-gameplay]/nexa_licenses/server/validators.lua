local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

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

local function hasLicenseType(payload)
    return normalizeId(payload.licenseTypeId) ~= nil or normalizeText(payload.licenseType) ~= nil
end

function validateLicenseIssuePayload(payload)
    if type(payload) ~= 'table' or normalizeId(payload.characterId) == nil or not hasLicenseType(payload) then
        return false, 'INVALID_INPUT'
    end

    if payload.expiresAt ~= nil and (type(payload.expiresAt) ~= 'string' or not payload.expiresAt:match('^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$')) then
        return false, 'INVALID_INPUT'
    end

    local reason = normalizeText(payload.reason)

    if reason ~= nil and #reason > NexaLicensesConfig.maxReasonLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateLicenseRevokePayload(payload)
    if type(payload) ~= 'table' or normalizeId(payload.licenseId) == nil then
        return false, 'INVALID_INPUT'
    end

    local reason = normalizeText(payload.reason)

    if reason ~= nil and #reason > NexaLicensesConfig.maxReasonLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateLicenseValidationPayload(payload)
    if type(payload) ~= 'table' or normalizeId(payload.characterId) == nil or not hasLicenseType(payload) then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateLicenseHistoryPayload(payload)
    if type(payload) ~= 'table' or normalizeId(payload.licenseId) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
