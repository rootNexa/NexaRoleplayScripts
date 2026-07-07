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

function validateWeazelCallsignPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.characterId ~= nil and normalizeId(payload.characterId) == nil then
        return false, 'INVALID_INPUT'
    end

    local callsign = normalizeText(payload.callsign, nil)

    if callsign ~= nil and #callsign > NexaWeazelConfig.maxCallsignLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateWeazelMemberPayload(payload)
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

function validateWeazelPressPassPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local ownerCharacterId = normalizeId(payload.ownerCharacterId)
    local note = normalizeText(payload.note, nil)

    if ownerCharacterId == nil then
        return false, 'INVALID_INPUT'
    end

    if note ~= nil and #note > NexaWeazelServer.maxPressNoteLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateWeazelAnnouncementPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local title = normalizeText(payload.title, nil)
    local body = normalizeText(payload.body, nil)

    if title == nil or body == nil then
        return false, 'INVALID_INPUT'
    end

    if #title > NexaWeazelServer.maxAnnouncementTitleLength or #body > NexaWeazelServer.maxAnnouncementBodyLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
