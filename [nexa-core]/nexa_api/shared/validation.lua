NexaApiValidation = {}
NexaApiResponse = {}

local function fail(code, message, details)
    return {
        ok = false,
        data = nil,
        error = {
            code = code or NexaApiConstants.errors.internal,
            message = message or 'Operation failed.',
            details = details
        }
    }
end

function NexaApiResponse.ok(data)
    return {
        ok = true,
        data = data,
        error = nil
    }
end

function NexaApiResponse.fail(code, message, details)
    return fail(code, message, details)
end

function NexaApiValidation.isName(value)
    return type(value) == 'string' and #value >= 2 and #value <= 64
end

function NexaApiValidation.isCallbackName(value)
    if not NexaApiValidation.isName(value) then
        return false
    end

    return value:sub(1, 5) == 'nexa:' or value:find('^[%w_%-]+:') ~= nil
end

function NexaApiValidation.isArray(value)
    if type(value) ~= 'table' then
        return false
    end

    local count = 0

    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
            return false
        end

        count = count + 1
    end

    for index = 1, count do
        if value[index] == nil then
            return false
        end
    end

    return true
end

function NexaApiValidation.valueType(value)
    if NexaApiValidation.isArray(value) then
        return 'array'
    end

    return type(value)
end

function NexaApiValidation.validatePrimitive(value, rules)
    if type(rules) ~= 'table' then
        return NexaApiResponse.ok(true)
    end

    local expectedType = rules.type

    if expectedType == 'table' and type(value) == 'table' then
        return NexaApiResponse.ok(true)
    end

    if expectedType and NexaApiValidation.valueType(value) ~= expectedType then
        return fail(NexaApiConstants.errors.invalid_payload, 'Payload field has an invalid type.', {
            expected = expectedType,
            actual = NexaApiValidation.valueType(value)
        })
    end

    if expectedType == 'string' then
        if rules.min and #value < rules.min then
            return fail(NexaApiConstants.errors.invalid_payload, 'Payload string is too short.')
        end

        if rules.max and #value > rules.max then
            return fail(NexaApiConstants.errors.invalid_payload, 'Payload string is too long.')
        end
    end

    if expectedType == 'number' then
        if rules.min and value < rules.min then
            return fail(NexaApiConstants.errors.invalid_payload, 'Payload number is too small.')
        end

        if rules.max and value > rules.max then
            return fail(NexaApiConstants.errors.invalid_payload, 'Payload number is too large.')
        end
    end

    return NexaApiResponse.ok(true)
end
