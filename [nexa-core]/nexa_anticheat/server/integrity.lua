function NexaAnticheatValidateResourceIntegrity(resourceName)
    if resourceName ~= nil and type(resourceName) ~= 'string' then
        return false, 'INVALID_INPUT'
    end

    local result = {}
    local expected = NexaAnticheatServer.expectedResources

    for name, expectedState in pairs(expected) do
        if resourceName == nil or resourceName == name then
            local actualState = GetResourceState(name)

            result[name] = {
                expected = expectedState,
                actual = actualState,
                valid = actualState == expectedState
            }
        end
    end

    if resourceName ~= nil and result[resourceName] == nil then
        return false, 'RESOURCE_NOT_REGISTERED'
    end

    for _, entry in pairs(result) do
        if entry.valid ~= true then
            return false, 'RESOURCE_INTEGRITY_FAILED', result
        end
    end

    return true, 'OK', result
end
