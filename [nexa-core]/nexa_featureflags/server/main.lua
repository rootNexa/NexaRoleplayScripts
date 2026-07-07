local flags = {}

for flagName, enabled in pairs(NexaFeatureFlagsConfig.defaults) do
    flags[flagName] = enabled
end

local function validateFlagName(flagName)
    if type(flagName) ~= 'string' or flagName == '' then
        return false
    end

    return flagName:match('^[%w_%.]+$') ~= nil
end

function isEnabled(flagName)
    if not validateFlagName(flagName) then
        return false
    end

    return flags[flagName] == true
end

function set(flagName, enabled)
    if not validateFlagName(flagName) then
        return {
            success = false,
            code = 'INVALID_INPUT',
            message = 'Feature-Schalter ist ungueltig.',
            data = nil,
            meta = nil,
            audit_id = nil
        }
    end

    flags[flagName] = enabled == true

    return {
        success = true,
        code = 'OK',
        message = 'Feature-Schalter wurde aktualisiert.',
        data = {
            flagName = flagName,
            enabled = flags[flagName]
        },
        meta = {
            persistent = false
        },
        audit_id = nil
    }
end

function reload()
    for flagName, enabled in pairs(NexaFeatureFlagsConfig.defaults) do
        flags[flagName] = enabled
    end

    return {
        success = true,
        code = 'OK',
        message = 'Feature-Schalter wurden neu geladen.',
        data = flags,
        meta = {
            source = 'config'
        },
        audit_id = nil
    }
end

function list()
    local result = {}

    for flagName, enabled in pairs(flags) do
        result[flagName] = enabled
    end

    return result
end

exports('isEnabled', isEnabled)
exports('set', set)
exports('reload', reload)
exports('list', list)
