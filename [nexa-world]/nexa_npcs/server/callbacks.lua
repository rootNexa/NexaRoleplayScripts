local CALLBACK_GET_AVAILABLE = 'nexa:npcs:cb:getAvailable'
local CALLBACK_VALIDATE_INTERACTION = 'nexa:npcs:cb:validateInteraction'

local function responseFail(code, message, details)
    return {
        ok = false,
        success = false,
        data = nil,
        error = {
            code = code,
            message = message,
            details = details
        },
        code = code,
        message = message,
        meta = details
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

    return exports.nexa_npcs['npcs.getAvailable'](source)
end)

exports.nexa_api:RegisterServerCallback(CALLBACK_VALIDATE_INTERACTION, function(source, payload)
    local rejected = rejectRequest(source, CALLBACK_VALIDATE_INTERACTION)

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_npcs['npcs.validateInteraction'](source, payload or {})
end)
