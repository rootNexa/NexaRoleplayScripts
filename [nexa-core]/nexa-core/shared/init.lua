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

local LOG_LEVELS = {
    debug = 10,
    info = 20,
    warn = 30,
    error = 40,
    audit = 50,
    security = 60
}

local LOG_LEVEL_NAMES = {
    [10] = 'debug',
    [20] = 'info',
    [30] = 'warn',
    [40] = 'error',
    [50] = 'audit',
    [60] = 'security'
}

local DEFAULT_LOG_LEVEL = Nexa.Config and Nexa.Config.debug and 'debug' or 'info'
local MAX_DEPTH = 5
local MAX_TABLE_KEYS = 50
local MAX_STRING_LENGTH = 512
local MAX_ENCODED_CONTEXT_LENGTH = 4096

local loggerState = {
    level = DEFAULT_LOG_LEVEL,
    adapters = {}
}

local sensitiveKeyPatterns = {
    'password',
    'passwd',
    'pwd',
    'token',
    'secret',
    'authorization',
    'auth',
    'apikey',
    'api_key',
    'key',
    'cookie',
    'session'
}

local function normalizeLevel(level)
    if type(level) ~= 'string' then
        return nil
    end

    level = level:lower()

    if not LOG_LEVELS[level] then
        return nil
    end

    return level
end

local function isLevelEnabled(level, configuredLevel)
    level = normalizeLevel(level)
    configuredLevel = normalizeLevel(configuredLevel) or loggerState.level

    if not level then
        return false
    end

    return LOG_LEVELS[level] >= LOG_LEVELS[configuredLevel]
end

local function isSensitiveKey(key)
    if type(key) ~= 'string' then
        return false
    end

    local normalized = key:lower()

    for _, pattern in ipairs(sensitiveKeyPatterns) do
        if normalized:find(pattern, 1, true) then
            return true
        end
    end

    return false
end

local function maskIpAddress(value)
    if type(value) ~= 'string' then
        return value
    end

    return value:gsub('(%d+)%.(%d+)%.(%d+)%.(%d+)', function(first, second)
        return ('%s.%s.x.x'):format(first, second)
    end)
end

local function truncateString(value)
    if #value <= MAX_STRING_LENGTH then
        return value
    end

    return value:sub(1, MAX_STRING_LENGTH) .. '<truncated>'
end

local function sanitizeValue(value, key, depth, seen)
    if isSensitiveKey(key) then
        return '<redacted>'
    end

    local valueType = type(value)

    if valueType == 'string' then
        return truncateString(maskIpAddress(value))
    end

    if valueType == 'number' or valueType == 'boolean' or value == nil then
        return value
    end

    if valueType ~= 'table' then
        return ('<%s>'):format(valueType)
    end

    if seen[value] then
        return '<cycle>'
    end

    if depth >= MAX_DEPTH then
        return '<max_depth>'
    end

    seen[value] = true

    local sanitized = {}
    local count = 0

    for nestedKey, nestedValue in pairs(value) do
        count = count + 1

        if count > MAX_TABLE_KEYS then
            sanitized.__truncated = true
            break
        end

        local safeKey = sanitizeValue(nestedKey, nil, depth + 1, seen)

        if type(safeKey) ~= 'string' and type(safeKey) ~= 'number' then
            safeKey = tostring(safeKey)
        end

        sanitized[safeKey] = sanitizeValue(nestedValue, safeKey, depth + 1, seen)
    end

    seen[value] = nil
    return sanitized
end

local function sanitizeContext(context)
    if context == nil then
        return nil
    end

    return sanitizeValue(context, nil, 0, {})
end

local function mergeContext(baseContext, context)
    local merged = {}

    if type(baseContext) == 'table' then
        for key, value in pairs(baseContext) do
            merged[key] = value
        end
    end

    if type(context) == 'table' then
        for key, value in pairs(context) do
            merged[key] = value
        end
    elseif context ~= nil then
        merged.value = context
    end

    return merged
end

local function encodeSafe(value)
    local ok, encoded = pcall(json.encode, value)

    if not ok then
        return json.encode({
            encodeError = tostring(encoded)
        })
    end

    return encoded
end

local function truncateEncodedContext(context)
    if context == nil then
        return nil
    end

    local encoded = encodeSafe(context)

    if #encoded <= MAX_ENCODED_CONTEXT_LENGTH then
        return context
    end

    return {
        __truncated = true,
        encodedLength = #encoded
    }
end

local function extractContextField(context, name)
    if type(context) ~= 'table' then
        return nil
    end

    return context[name]
end

local function buildEntry(level, category, message, context)
    local safeContext = truncateEncodedContext(sanitizeContext(context))

    return {
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        level = level,
        resource = GetCurrentResourceName and GetCurrentResourceName() or NEXA_CONSTANTS.resourceName,
        module = extractContextField(safeContext, 'module') or NEXA_CONSTANTS.resourceName,
        category = type(category) == 'string' and category ~= '' and category or 'core',
        message = type(message) == 'string' and truncateString(message) or tostring(message),
        context = safeContext,
        source = extractContextField(safeContext, 'source'),
        characterId = extractContextField(safeContext, 'characterId') or extractContextField(safeContext, 'character_id'),
        correlationId = extractContextField(safeContext, 'correlationId') or extractContextField(safeContext, 'correlation_id')
    }
end

local function adapterAllows(adapter, entry)
    if type(adapter) ~= 'table' then
        return false
    end

    if adapter.level and not isLevelEnabled(entry.level, adapter.level) then
        return false
    end

    if type(adapter.categories) == 'table' then
        local allowed = false

        for _, category in ipairs(adapter.categories) do
            if category == entry.category then
                allowed = true
                break
            end
        end

        if not allowed then
            return false
        end
    end

    return true
end

local function emitToAdapters(entry)
    for name, adapter in pairs(loggerState.adapters) do
        if adapterAllows(adapter, entry) then
            local ok, err = pcall(adapter.write, entry)

            if not ok and name ~= 'console' then
                local fallback = {
                    timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                    level = 'error',
                    resource = NEXA_CONSTANTS.resourceName,
                    module = 'logger',
                    category = 'logger.adapter',
                    message = 'Log-Adapter fehlgeschlagen.',
                    context = {
                        adapter = name,
                        error = tostring(err)
                    }
                }

                local console = loggerState.adapters.console

                if console and type(console.write) == 'function' then
                    pcall(console.write, fallback)
                end
            end
        end
    end
end

local function write(level, category, message, context)
    local requestedLevel = level
    level = normalizeLevel(level)

    if not level then
        level = 'info'
        category = 'logger'
        message = ('Unbekanntes Log-Level verwendet: %s'):format(tostring(requestedLevel))
    end

    if not isLevelEnabled(level) then
        return nil
    end

    local entry = buildEntry(level, category, message, context)
    emitToAdapters(entry)
    return entry
end

local function registerConsoleAdapter()
    loggerState.adapters.console = {
        level = 'debug',
        write = function(entry)
            local output = {
                timestamp = entry.timestamp,
                level = entry.level,
                resource = entry.resource,
                module = entry.module,
                category = entry.category,
                message = entry.message,
                source = entry.source,
                characterId = entry.characterId,
                correlationId = entry.correlationId,
                context = entry.context
            }

            print(('[%s] [%s] [%s] %s'):format(entry.resource, entry.level, entry.category, encodeSafe(output)))
        end
    }
end

local function makeContextLogger(baseContext)
    local scoped = {}

    function scoped.Debug(category, message, context)
        return write('debug', category, message, mergeContext(baseContext, context))
    end

    function scoped.Info(category, message, context)
        return write('info', category, message, mergeContext(baseContext, context))
    end

    function scoped.Warn(category, message, context)
        return write('warn', category, message, mergeContext(baseContext, context))
    end

    function scoped.Error(category, message, context)
        return write('error', category, message, mergeContext(baseContext, context))
    end

    function scoped.Audit(category, message, context)
        return write('audit', category, message, mergeContext(baseContext, context))
    end

    function scoped.Security(category, message, context)
        return write('security', category, message, mergeContext(baseContext, context))
    end

    function scoped.WithContext(context)
        return makeContextLogger(mergeContext(baseContext, context))
    end

    return scoped
end

registerConsoleAdapter()

function Nexa.Logger.Debug(category, message, context)
    return write('debug', category, message, context)
end

function Nexa.Logger.Info(category, message, context)
    return write('info', category, message, context)
end

function Nexa.Logger.Warn(category, message, context)
    return write('warn', category, message, context)
end

function Nexa.Logger.Error(category, message, context)
    return write('error', category, message, context)
end

function Nexa.Logger.Audit(category, message, context)
    return write('audit', category, message, context)
end

function Nexa.Logger.Security(category, message, context)
    return write('security', category, message, context)
end

function Nexa.Logger.WithContext(context)
    return makeContextLogger(type(context) == 'table' and context or {
        value = context
    })
end

function Nexa.Logger.SetLevel(level)
    level = normalizeLevel(level)

    if not level then
        return false, 'UNKNOWN_LEVEL'
    end

    loggerState.level = level
    return true, nil
end

function Nexa.Logger.RegisterAdapter(name, adapter)
    if type(name) ~= 'string' or name == '' or type(adapter) ~= 'table' or type(adapter.write) ~= 'function' then
        return false, 'INVALID_ADAPTER'
    end

    local adapterLevel = adapter.level and normalizeLevel(adapter.level) or nil

    if adapter.level and not adapterLevel then
        return false, 'UNKNOWN_LEVEL'
    end

    loggerState.adapters[name] = {
        level = adapterLevel,
        categories = adapter.categories,
        write = adapter.write
    }

    return true, nil
end

function Nexa.Logger.RemoveAdapter(name)
    if type(name) ~= 'string' or name == '' or name == 'console' then
        return false, 'INVALID_ADAPTER'
    end

    loggerState.adapters[name] = nil
    return true, nil
end

function Nexa.Logger.GetLevel()
    return loggerState.level
end

function Nexa.Logger.GetLevels()
    return LOG_LEVEL_NAMES
end

function Nexa.Logger.Sanitize(context)
    return truncateEncodedContext(sanitizeContext(context))
end

function Nexa.Logger.info(message, context)
    return write('info', 'core', message, context)
end

function Nexa.Logger.warn(message, context)
    return write('warn', 'core', message, context)
end

function Nexa.Logger.error(message, context)
    return write('error', 'core', message, context)
end

function Nexa.Logger.debug(message, context)
    return write('debug', 'core', message, context)
end

function Nexa.Log(level, message, context)
    return write(level or 'info', 'core', message, context)
end
