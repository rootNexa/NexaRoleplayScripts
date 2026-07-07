local publicConfig = NexaConfigUtils.copyTable(NexaConfigShared.public)

function getPublicConfig()
    return NexaConfigUtils.copyTable(publicConfig)
end

function get(key, fallback)
    local value = NexaConfigUtils.readPath(publicConfig, key)

    if value == nil then
        return fallback
    end

    return value
end

exports('getPublicConfig', getPublicConfig)
exports('get', get)
