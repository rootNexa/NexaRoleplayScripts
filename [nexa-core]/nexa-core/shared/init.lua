Nexa = Nexa or {}
Nexa.Constants = NEXA_CONSTANTS
Nexa.Config = NexaConfig
Nexa.Version = NEXA_CONSTANTS.version

local function makeResponse(success, code, message, data, meta)
    return {
        success = success == true,
        code = code or (success and NEXA_CONSTANTS.errors.ok or NEXA_CONSTANTS.errors.internal),
        message = message or '',
        data = data,
        meta = meta
    }
end

Nexa.Response = setmetatable({
    ok = function(data, meta, message)
        return makeResponse(true, NEXA_CONSTANTS.errors.ok, message or 'OK', data, meta)
    end,

    fail = function(code, message, details)
        return makeResponse(false, code or NEXA_CONSTANTS.errors.internal, message or 'Der Vorgang konnte nicht abgeschlossen werden.', nil, details)
    end
}, {
    __call = function(_, success, code, message, data, meta)
        return makeResponse(success, code, message, data, meta)
    end
})

Nexa.Logger = Nexa.Logger or {}

local function log(level, message, context)
    local prefix = ('[%s] [%s]'):format(NEXA_CONSTANTS.resourceName, level or 'info')
    local encodedContext = ''

    if context ~= nil then
        encodedContext = (' %s'):format(json.encode(context))
    end

    print(('%s %s%s'):format(prefix, message, encodedContext))
end

function Nexa.Logger.info(message, context)
    log('info', message, context)
end

function Nexa.Logger.warn(message, context)
    log('warn', message, context)
end

function Nexa.Logger.error(message, context)
    log('error', message, context)
end

function Nexa.Logger.debug(message, context)
    if Nexa.Config and Nexa.Config.debug then
        log('debug', message, context)
    end
end

function Nexa.Log(level, message, context)
    local logger = Nexa.Logger[level or 'info']

    if logger then
        logger(message, context)
        return
    end

    log(level or 'info', message, context)
end
