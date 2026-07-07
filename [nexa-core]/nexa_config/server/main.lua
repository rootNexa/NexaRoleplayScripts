local environment = GetConvar('nexa:environment', NEXA_CONFIG.defaultEnvironment)
local debugEnabled = GetConvar('nexa:debug', 'false') == 'true'

local function validateEnvironment()
    if not NexaConfigShared.environments[environment] then
        error(('Ungueltige Nexa-Umgebung: %s'):format(environment), 0)
    end

    if environment == 'production' and debugEnabled and not NexaConfigServer.productionDebugAllowed then
        error('Debug darf in Production nicht aktiv sein.', 0)
    end
end

local function getConfigValue(key, fallback)
    local value = NexaConfigUtils.readPath(NexaConfigShared, key)

    if value == nil then
        return fallback
    end

    return value
end

function get(key, fallback)
    if key == 'environment' then
        return environment
    end

    if key == 'debug' then
        return debugEnabled
    end

    return getConfigValue(key, fallback)
end

function getEnvironment()
    return environment
end

function isProduction()
    return environment == 'production'
end

function isDebugEnabled()
    return debugEnabled
end

function getPublicConfig()
    return NexaConfigUtils.copyTable(NexaConfigShared.public)
end

validateEnvironment()

exports('get', get)
exports('getEnvironment', getEnvironment)
exports('isProduction', isProduction)
exports('isDebugEnabled', isDebugEnabled)
exports('getPublicConfig', getPublicConfig)
