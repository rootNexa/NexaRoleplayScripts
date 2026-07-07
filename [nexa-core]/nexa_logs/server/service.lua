local entries = {}

local function getMinimumLevel()
    local configuredLevel = GetConvar('nexa:logLevel', NexaLogsConfig.defaultLevel)
    return NexaLogsConfig.levels[configuredLevel] or NexaLogsConfig.levels.info
end

local function shouldWrite(level)
    local currentLevel = NexaLogsConfig.levels[level] or NexaLogsConfig.levels.info
    return currentLevel >= getMinimumLevel()
end

local function normalizeMessage(message)
    if type(message) ~= 'string' or message == '' then
        return 'Logeintrag ohne Nachricht.'
    end

    local maxLength = 512

    if GetResourceState('nexa_config') == 'started' then
        local ok, configuredMaxLength = pcall(function()
            return exports.nexa_config:get('limits.maxLogMessageLength', maxLength)
        end)

        if ok and tonumber(configuredMaxLength) ~= nil then
            maxLength = tonumber(configuredMaxLength)
        end
    end

    if #message > maxLength then
        return message:sub(1, maxLength)
    end

    return message
end

function writeLog(level, resourceName, message, metadata)
    local normalizedLevel = level or 'info'

    if not NexaLogsConfig.levels[normalizedLevel] then
        normalizedLevel = 'info'
    end

    local entry = {
        level = normalizedLevel,
        resourceName = resourceName or GetInvokingResource() or NEXA_LOGS.resourceName,
        message = normalizeMessage(message),
        metadata = metadata or {},
        createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    entries[#entries + 1] = entry

    if #entries > NexaLogsServer.bufferLimit then
        table.remove(entries, 1)
    end

    if shouldWrite(normalizedLevel) then
        print(NexaFormatLogEntry(entry))
    end

    return entry
end

function getRecentLogs(limit)
    local requestedLimit = tonumber(limit) or 50
    local result = {}
    local startIndex = math.max(1, #entries - requestedLimit + 1)

    for index = startIndex, #entries do
        result[#result + 1] = entries[index]
    end

    return result
end
