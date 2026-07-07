local maxReasonLength = 255

local function normalizePositiveInteger(value)
    local number = tonumber(value)

    if number == nil or number <= 0 or math.floor(number) ~= number then
        return nil
    end

    return number
end

local function normalizeText(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' or #trimmed > maxLength then
        return nil
    end

    return trimmed
end

function validateIllegalSource(source)
    return type(source) == 'number' and source > 0
end

function validateReputationPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local characterId = normalizePositiveInteger(payload.characterId)
    local reputationType = normalizeText(payload.reputationType or 'general', 32)
    local reason = normalizeText(payload.reason or 'illegal_core', maxReasonLength)
    local delta = tonumber(payload.delta)

    if characterId == nil or reputationType == nil or reason == nil or not NexaIllegalCoreConfig.reputationTypes[reputationType] then
        return false, 'INVALID_INPUT'
    end

    if delta == nil or math.floor(delta) ~= delta or math.abs(delta) > NexaIllegalCoreConfig.maxReputationDelta then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateSnapshotPayload(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.characterId ~= nil and normalizePositiveInteger(payload.characterId) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.reputationType ~= nil then
        local reputationType = normalizeText(payload.reputationType, 32)

        if reputationType == nil or not NexaIllegalCoreConfig.reputationTypes[reputationType] then
            return false, 'INVALID_INPUT'
        end
    end

    return true, 'OK'
end

function normalizeIllegalAction(value)
    local action = normalizeText(value or 'illegal.contact', 64)

    if action == nil then
        return nil
    end

    return action
end

function getIllegalActiveCharacterId(source)
    local active = exports.nexa_api['character.getActive'](source)

    if active == nil or not active.success or active.data == nil or active.data.character == nil then
        return nil
    end

    return active.data.character.id
end
