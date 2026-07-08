NexaLib.Logger = NexaLib.Logger or {}

local function encodeData(data)
    if data == nil then
        return ''
    end

    local ok, encoded = pcall(json.encode, data)

    if not ok then
        return ' {"error":"log_encode_failed"}'
    end

    return (' %s'):format(encoded)
end

local function write(level, resource, message, data)
    resource = type(resource) == 'string' and resource or 'nexa'
    message = type(message) == 'string' and message or ''

    print(('[%s] [%s] %s%s'):format(resource, level, message, encodeData(data)))
end

function NexaLib.Logger.info(resource, message, data)
    write('info', resource, message, data)
end

function NexaLib.Logger.warn(resource, message, data)
    write('warn', resource, message, data)
end

function NexaLib.Logger.error(resource, message, data)
    write('error', resource, message, data)
end

function NexaLib.Logger.debug(resource, message, data)
    if GetConvar('nexa:debug', 'false') == 'true' then
        write('debug', resource, message, data)
    end
end
