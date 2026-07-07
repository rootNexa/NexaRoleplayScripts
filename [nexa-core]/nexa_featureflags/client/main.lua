local clientFlags = NexaFeatureFlagsConfig.defaults

function isEnabled(flagName)
    if type(flagName) ~= 'string' or flagName == '' then
        return false
    end

    return clientFlags[flagName] == true
end

exports('isEnabled', isEnabled)
