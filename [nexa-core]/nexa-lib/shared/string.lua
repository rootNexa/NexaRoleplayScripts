NexaLib.String = NexaLib.String or {}

function NexaLib.String.trim(value)
    if type(value) ~= 'string' then
        return nil
    end

    return value:match('^%s*(.-)%s*$')
end

function NexaLib.String.lower(value)
    return type(value) == 'string' and string.lower(value) or value
end

function NexaLib.String.upper(value)
    return type(value) == 'string' and string.upper(value) or value
end

function NexaLib.String.startsWith(value, prefix)
    if type(value) ~= 'string' or type(prefix) ~= 'string' then
        return false
    end

    return value:sub(1, #prefix) == prefix
end

function NexaLib.String.endsWith(value, suffix)
    if type(value) ~= 'string' or type(suffix) ~= 'string' then
        return false
    end

    return suffix == '' or value:sub(-#suffix) == suffix
end
