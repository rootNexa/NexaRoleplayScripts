local allowedDispatchStatus = {
    open = true,
    assigned = true,
    closed = true,
    cancelled = true
}

local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeText(value, fallback)
    if value == nil then
        return fallback
    end

    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return fallback
    end

    return trimmed
end

function validateLspdCallsignPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.characterId ~= nil and normalizeId(payload.characterId) == nil then
        return false, 'INVALID_INPUT'
    end

    local callsign = normalizeText(payload.callsign, nil)

    if callsign ~= nil and #callsign > NexaLspdConfig.maxCallsignLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateLspdDispatchPayload(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local status = normalizeText(payload.status, nil)

    if status ~= nil and not allowedDispatchStatus[status] then
        return false, 'INVALID_INPUT'
    end

    if payload.limit ~= nil and normalizeId(payload.limit) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateLspdMemberPayload(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.limit ~= nil and normalizeId(payload.limit) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
