NexaLib.Validate = NexaLib.Validate or {}

function NexaLib.Validate.isString(value)
    return type(value) == 'string'
end

function NexaLib.Validate.isNonEmptyString(value)
    return type(value) == 'string' and NexaLib.String.trim(value) ~= ''
end

function NexaLib.Validate.maxLength(value, max)
    return type(value) == 'string' and type(max) == 'number' and #value <= max
end

function NexaLib.Validate.isNumber(value)
    return type(value) == 'number'
end

function NexaLib.Validate.isInteger(value)
    return type(value) == 'number' and value % 1 == 0
end

function NexaLib.Validate.isBoolean(value)
    return type(value) == 'boolean'
end

function NexaLib.Validate.isDate(value)
    if type(value) ~= 'string' or not value:match('^%d%d%d%d%-%d%d%-%d%d$') then
        return false
    end

    local month = tonumber(value:sub(6, 7))
    local day = tonumber(value:sub(9, 10))

    return month ~= nil and day ~= nil and month >= 1 and month <= 12 and day >= 1 and day <= 31
end

function NexaLib.Validate.sanitizeString(value)
    value = NexaLib.String.trim(value)

    if not value then
        return nil
    end

    value = value:gsub('[%z\1-\31]', '')
    return value
end
