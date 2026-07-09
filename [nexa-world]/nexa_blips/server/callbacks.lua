local CALLBACK_GET_AVAILABLE = 'nexa:blips:cb:getAvailable'

local function responseFail(code, message, details)
    return {
        ok = false,
        data = nil,
        error = {
            code = code,
            message = message,
            details = details
        }
    }
end

local function rejectRequest(source, eventName)
    if not exports.nexa_security:validateSource(source) then
        return responseFail('INVALID_INPUT', 'Ungueltige Anfrage.', nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return responseFail('RATE_LIMITED', 'Bitte warte einen Moment.', nil)
    end

    return nil
end

exports.nexa_api:RegisterServerCallback(CALLBACK_GET_AVAILABLE, function(source)
    local rejected = rejectRequest(source, CALLBACK_GET_AVAILABLE)

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_blips['blips.getAvailable'](source)
end)
