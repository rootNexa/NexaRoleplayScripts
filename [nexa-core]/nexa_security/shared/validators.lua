function NexaSecurityValidateEventName(eventName)
    if type(eventName) ~= 'string' or eventName == '' then
        return false, 'INVALID_EVENT_NAME'
    end

    local maxLength = exports.nexa_config:get('limits.maxEventNameLength', 128)

    if #eventName > maxLength then
        return false, 'EVENT_NAME_TOO_LONG'
    end

    if not eventName:match('^[%w%._:%-]+$') then
        return false, 'EVENT_NAME_INVALID_CHARACTERS'
    end

    return true, 'OK'
end
