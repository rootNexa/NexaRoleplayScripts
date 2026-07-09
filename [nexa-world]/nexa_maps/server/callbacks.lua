local CALLBACK_LIST = 'nexa:maps:cb:list'
local CALLBACK_GET = 'nexa:maps:cb:get'

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

exports.nexa_api:RegisterServerCallback(CALLBACK_LIST, function(source, payload)
    local rejected = rejectRequest(source, CALLBACK_LIST)

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_maps['maps.list'](source, payload or {})
end)

exports.nexa_api:RegisterServerCallback(CALLBACK_GET, function(source, mapId)
    local rejected = rejectRequest(source, CALLBACK_GET)

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_maps['maps.get'](source, mapId)
end)
