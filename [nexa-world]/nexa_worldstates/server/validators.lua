local allowedScopes = {
    global = true,
    resource = true
}

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

local function normalizeName(value, maxLength)
    local name = normalizeText(value, nil, maxLength)

    if name == nil or name:match('^[%w_.:-]+$') == nil then
        return nil
    end

    return name
end

local function normalizeScope(value)
    local scope = normalizeText(value, 'global', 32)

    if scope == nil then
        return nil
    end

    scope = scope:lower()

    if not allowedScopes[scope] then
        return nil
    end

    return scope
end

function validateWorldStatePayload(payload, requireValue)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local scope = normalizeScope(payload.scope)
    local stateName = normalizeName(payload.stateName or payload.name, NexaWorldStatesServer.maxStateNameLength)

    if scope == nil or stateName == nil then
        return false, 'INVALID_INPUT'
    end

    if scope == 'resource'
        and normalizeName(payload.resourceName, NexaWorldStatesServer.maxResourceNameLength) == nil then
        return false, 'INVALID_INPUT'
    end

    if requireValue and payload.value == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.metadata ~= nil and type(payload.metadata) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.ttlSeconds ~= nil then
        local ttl = tonumber(payload.ttlSeconds)

        if ttl == nil or ttl < 1 or math.floor(ttl) ~= ttl then
            return false, 'INVALID_INPUT'
        end
    end

    return true, 'OK'
end

function validateWorldStateListPayload(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.scope ~= nil and normalizeScope(payload.scope) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.resourceName ~= nil
        and normalizeName(payload.resourceName, NexaWorldStatesServer.maxResourceNameLength) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.limit ~= nil then
        local limit = tonumber(payload.limit)

        if limit == nil or limit < 1 or math.floor(limit) ~= limit then
            return false, 'INVALID_INPUT'
        end
    end

    return true, 'OK'
end

function validateResourceStatePayload(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.resources ~= nil and type(payload.resources) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if type(payload.resources) == 'table' then
        for _, resourceName in ipairs(payload.resources) do
            if normalizeName(resourceName, NexaWorldStatesServer.maxResourceNameLength) == nil then
                return false, 'INVALID_INPUT'
            end
        end
    end

    return true, 'OK'
end
