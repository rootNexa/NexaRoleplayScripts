local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeAmount(value)
    local number = tonumber(value)

    if number == nil or number < 1 or number > NexaBusinessConfig.maxAmount then
        return nil
    end

    if math.floor(number) ~= number then
        return nil
    end

    return number
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

function validateCreateBusinessPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local name = normalizeText(payload.name)
    local label = normalizeText(payload.label or payload.name)

    if name == nil or label == nil or #name > NexaBusinessConfig.maxNameLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateBusinessReferencePayload(payload)
    if type(payload) ~= 'table' or normalizeId(payload.businessId) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateBusinessMemberPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeId(payload.businessId) == nil or normalizeId(payload.characterId) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.roleName ~= nil and not NexaBusinessServer.allowedRoles[payload.roleName] then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateBusinessTransferPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeId(payload.businessId) == nil or normalizeId(payload.toAccountId) == nil then
        return false, 'INVALID_INPUT'
    end

    if normalizeAmount(payload.amount) == nil then
        return false, 'INVALID_INPUT'
    end

    local reason = normalizeText(payload.reason)

    if reason ~= nil and #reason > NexaBusinessConfig.maxReasonLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
