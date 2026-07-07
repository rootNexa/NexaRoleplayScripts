local locale = NexaLocaleDe

function get(key, fallback)
    local value = NexaLocalesUtils.readPath(locale, key)

    if value == nil then
        return fallback
    end

    return value
end

function exists(key)
    return NexaLocalesUtils.readPath(locale, key) ~= nil
end

exports('get', get)
exports('exists', exists)
