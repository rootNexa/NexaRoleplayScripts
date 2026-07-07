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

function NexaAnticheatValidateSource(value)
    local sourceNumber = tonumber(value)

    if sourceNumber == nil or sourceNumber <= 0 then
        return false, 'INVALID_SOURCE'
    end

    return true, 'OK', sourceNumber
end

function NexaAnticheatValidateEventName(eventName)
    local normalized = normalizeText(eventName, 128)

    if normalized == nil then
        return false, 'INVALID_EVENT_NAME'
    end

    if not normalized:match('^[%w%._:%-]+$') then
        return false, 'INVALID_EVENT_NAME'
    end

    return true, 'OK', normalized
end

function NexaAnticheatValidatePayloadShape(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_PAYLOAD'
    end

    local keys = 0

    for _, value in pairs(payload) do
        keys = keys + 1

        if keys > NexaAnticheatServer.maxPayloadKeys then
            return false, 'PAYLOAD_TOO_LARGE'
        end

        if type(value) == 'string' and #value > NexaAnticheatServer.maxStringLength then
            return false, 'PAYLOAD_TOO_LARGE'
        end
    end

    return true, 'OK'
end

local function estimatePayloadSize(value, depth)
    local valueType = type(value)

    if value == nil then
        return 0
    end

    if valueType == 'string' then
        return #value
    end

    if valueType == 'number' or valueType == 'boolean' then
        return #tostring(value)
    end

    if valueType ~= 'table' then
        return 0
    end

    if depth > NexaAnticheatServer.maxPayloadDepth then
        return NexaAnticheatServer.maxPayloadBytes + 1
    end

    local size = 0

    for key, child in pairs(value) do
        size = size + estimatePayloadSize(key, depth + 1)
        size = size + estimatePayloadSize(child, depth + 1)

        if size > NexaAnticheatServer.maxPayloadBytes then
            return size
        end
    end

    return size
end

local function validatePayloadTypes(value, depth)
    local valueType = type(value)

    if NexaAnticheatServer.allowedPayloadTypes[valueType] ~= true then
        return false, 'INVALID_PAYLOAD_TYPE'
    end

    if valueType == 'string' and #value > NexaAnticheatServer.maxStringLength then
        return false, 'PAYLOAD_TOO_LARGE'
    end

    if valueType ~= 'table' then
        return true, 'OK'
    end

    if depth > NexaAnticheatServer.maxPayloadDepth then
        return false, 'PAYLOAD_TOO_DEEP'
    end

    local keys = 0

    for key, child in pairs(value) do
        keys = keys + 1

        if keys > NexaAnticheatServer.maxPayloadKeys then
            return false, 'PAYLOAD_TOO_LARGE'
        end

        local keyValid, keyCode = validatePayloadTypes(key, depth + 1)

        if not keyValid then
            return false, keyCode
        end

        local childValid, childCode = validatePayloadTypes(child, depth + 1)

        if not childValid then
            return false, childCode
        end
    end

    return true, 'OK'
end

function NexaAnticheatValidatePayloadSize(payload)
    if estimatePayloadSize(payload, 1) > NexaAnticheatServer.maxPayloadBytes then
        return false, 'PAYLOAD_TOO_LARGE'
    end

    return true, 'OK'
end

function NexaAnticheatValidatePayloadTypes(payload)
    return validatePayloadTypes(payload, 1)
end

function NexaAnticheatValidateSchema(payload, schema)
    if schema == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_PAYLOAD'
    end

    for fieldName in pairs(payload) do
        if schema[fieldName] == nil then
            return false, 'PAYLOAD_FIELD_NOT_ALLOWED'
        end
    end

    for fieldName, rule in pairs(schema) do
        local value = payload[fieldName]

        if rule.required and value == nil then
            return false, 'INVALID_PAYLOAD'
        end

        if value ~= nil and rule.type ~= nil and type(value) ~= rule.type then
            return false, 'INVALID_PAYLOAD'
        end

        if value ~= nil and rule.type == 'string' and rule.maxLength ~= nil and #value > rule.maxLength then
            return false, 'PAYLOAD_TOO_LARGE'
        end
    end

    return true, 'OK'
end
