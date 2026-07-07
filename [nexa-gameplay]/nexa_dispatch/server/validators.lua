local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizePriority(value)
    local number = tonumber(value) or NexaDispatchConfig.defaultPriority

    if math.floor(number) ~= number then
        return nil
    end

    if number < NexaDispatchConfig.minPriority or number > NexaDispatchConfig.maxPriority then
        return nil
    end

    return number
end

local function normalizeText(value, fallback, maxLength)
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

    if maxLength ~= nil and #trimmed > maxLength then
        return nil
    end

    return trimmed
end

local function hasValidLocation(location)
    if location == nil then
        return true
    end

    if type(location) ~= 'table' then
        return false
    end

    for _, key in ipairs({ 'x', 'y', 'z' }) do
        if location[key] ~= nil and tonumber(location[key]) == nil then
            return false
        end
    end

    return true
end

local function hasValidFactions(factions)
    if factions == nil then
        return true
    end

    if type(factions) ~= 'table' or #factions < 1 or #factions > 6 then
        return false
    end

    for _, factionName in ipairs(factions) do
        if normalizeText(factionName, nil, NexaDispatchConfig.maxFactionNameLength) == nil then
            return false
        end
    end

    return true
end

function validateCreateCallPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local category = normalizeText(payload.category, NexaDispatchConfig.defaultCategory, NexaDispatchConfig.maxCategoryLength)

    if category == nil or not NexaDispatchServer.allowedCategories[category] then
        return false, 'INVALID_INPUT'
    end

    if normalizePriority(payload.priority) == nil then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(payload.description, nil, NexaDispatchConfig.maxDescriptionLength) == nil then
        return false, 'INVALID_INPUT'
    end

    if not hasValidLocation(payload.location) or not hasValidFactions(payload.targetFactions) then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateListCallsPayload(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.status ~= nil and NexaDispatchServer.statusTransitions[payload.status] == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.faction ~= nil and normalizeText(payload.faction, nil, NexaDispatchConfig.maxFactionNameLength) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateCallReferencePayload(payload)
    if type(payload) ~= 'table' or normalizeId(payload.callId) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateAssignPayload(payload)
    local valid, code = validateCallReferencePayload(payload)

    if not valid then
        return false, code
    end

    if payload.characterId ~= nil and normalizeId(payload.characterId) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.faction ~= nil and normalizeText(payload.faction, nil, NexaDispatchConfig.maxFactionNameLength) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateStatusPayload(payload)
    local valid, code = validateCallReferencePayload(payload)

    if not valid then
        return false, code
    end

    if type(payload.status) ~= 'string' or NexaDispatchServer.statusTransitions[payload.status] == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validatePriorityPayload(payload)
    local valid, code = validateCallReferencePayload(payload)

    if not valid then
        return false, code
    end

    if normalizePriority(payload.priority) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
