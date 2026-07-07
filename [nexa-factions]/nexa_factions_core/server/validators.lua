local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeAmount(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    if math.floor(number) ~= number then
        return nil
    end

    return number
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

function validateFactionReferencePayload(payload, allowEmpty)
    if payload == nil and allowEmpty then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeId(payload.factionId) ~= nil then
        return true, 'OK'
    end

    local factionName = normalizeText(payload.factionName, nil)

    if factionName ~= nil and NexaFactionsServer.officialFactions[factionName] then
        return true, 'OK'
    end

    return allowEmpty == true, allowEmpty == true and 'OK' or 'INVALID_INPUT'
end

function validateCallsignPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local validReference = validateFactionReferencePayload(payload, true)

    if not validReference then
        return false, 'INVALID_INPUT'
    end

    if payload.characterId ~= nil and normalizeId(payload.characterId) == nil then
        return false, 'INVALID_INPUT'
    end

    local callsign = normalizeText(payload.callsign, nil)

    if callsign ~= nil and #callsign > NexaFactionsConfig.maxCallsignLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateAssignMemberPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if not validateFactionReferencePayload(payload, false) then
        return false, 'INVALID_INPUT'
    end

    if normalizeId(payload.characterId) == nil then
        return false, 'INVALID_INPUT'
    end

    if normalizeId(payload.gradeId) == nil and normalizeId(payload.gradeLevel) == nil then
        return false, 'INVALID_INPUT'
    end

    local callsign = normalizeText(payload.callsign, nil)

    if callsign ~= nil and #callsign > NexaFactionsConfig.maxCallsignLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateFactionTransferPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if not validateFactionReferencePayload(payload, true) then
        return false, 'INVALID_INPUT'
    end

    if normalizeId(payload.toAccountId) == nil or normalizeAmount(payload.amount) == nil then
        return false, 'INVALID_INPUT'
    end

    local reason = normalizeText(payload.reason, nil)

    if reason == nil or #reason > 128 then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
