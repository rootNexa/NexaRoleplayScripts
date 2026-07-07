local secureEvents = {}

local function copyTable(value)
    if type(value) ~= 'table' then
        return value
    end

    local result = {}

    for key, child in pairs(value) do
        result[key] = copyTable(child)
    end

    return result
end

function NexaAnticheatRegisterSecureEvent(eventName, options)
    local eventValid, eventCode, normalizedEventName = NexaAnticheatValidateEventName(eventName)

    if not eventValid then
        return false, eventCode
    end

    if options ~= nil and type(options) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if NexaAnticheatIsDeniedEvent(normalizedEventName) then
        return false, 'EVENT_DENIED'
    end

    if not NexaAnticheatIsAllowedEvent(normalizedEventName) then
        return false, 'EVENT_NOT_ALLOWED'
    end

    if secureEvents[normalizedEventName] ~= nil then
        return false, 'EVENT_ALREADY_REGISTERED'
    end

    local normalizedOptions = options or {}

    secureEvents[normalizedEventName] = {
        eventName = normalizedEventName,
        critical = normalizedOptions.critical == true,
        requireToken = normalizedOptions.requireToken ~= false,
        consumeToken = normalizedOptions.consumeToken ~= false,
        requireReplayProtection = normalizedOptions.requireReplayProtection ~= false,
        allowedResources = normalizedOptions.allowedResources or {},
        payload = normalizedOptions.payload,
        registeredBy = GetInvokingResource() or NEXA_ANTICHEAT.resourceName,
        registeredAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    return true, 'OK', copyTable(secureEvents[normalizedEventName])
end

function NexaAnticheatGetSecureEvent(eventName)
    local eventValid, _, normalizedEventName = NexaAnticheatValidateEventName(eventName)

    if not eventValid then
        return nil
    end

    return secureEvents[normalizedEventName]
end

function NexaAnticheatListSecureEvents()
    return copyTable(secureEvents)
end

for eventName, options in pairs(NexaAnticheatServer.secureEvents) do
    NexaAnticheatRegisterSecureEvent(eventName, options)
end
