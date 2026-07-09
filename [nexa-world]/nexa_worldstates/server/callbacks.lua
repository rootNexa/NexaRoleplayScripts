local CALLBACKS = {
    get = 'nexa:worldstates:cb:get',
    list = 'nexa:worldstates:cb:list',
    set = 'nexa:worldstates:cb:set',
    clear = 'nexa:worldstates:cb:clear',
    resources = 'nexa:worldstates:cb:resources'
}

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

local function validateOrFail(valid, code, message)
    if valid then
        return nil
    end

    return responseFail(code, message, nil)
end

exports.nexa_api:RegisterServerCallback(CALLBACKS.get, function(source, payload)
    local rejected = rejectRequest(source, CALLBACKS.get)

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateWorldStatePayload(payload, false)
    local invalid = validateOrFail(valid, code, 'Ungueltige World-State-Anfrage.')

    if invalid ~= nil then
        return invalid
    end

    return exports.nexa_worldstates['worldstates.getState'](source, payload)
end)

exports.nexa_api:RegisterServerCallback(CALLBACKS.list, function(source, payload)
    local rejected = rejectRequest(source, CALLBACKS.list)

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateWorldStateListPayload(payload)
    local invalid = validateOrFail(valid, code, 'Ungueltige World-State-Liste.')

    if invalid ~= nil then
        return invalid
    end

    return exports.nexa_worldstates['worldstates.listStates'](source, payload)
end)

exports.nexa_api:RegisterServerCallback(CALLBACKS.set, function(source, payload)
    local rejected = rejectRequest(source, CALLBACKS.set)

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateWorldStatePayload(payload, true)
    local invalid = validateOrFail(valid, code, 'Ungueltige World-State-Daten.')

    if invalid ~= nil then
        return invalid
    end

    return exports.nexa_worldstates['worldstates.setState'](source, payload)
end)

exports.nexa_api:RegisterServerCallback(CALLBACKS.clear, function(source, payload)
    local rejected = rejectRequest(source, CALLBACKS.clear)

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateWorldStatePayload(payload, false)
    local invalid = validateOrFail(valid, code, 'Ungueltige World-State-Daten.')

    if invalid ~= nil then
        return invalid
    end

    return exports.nexa_worldstates['worldstates.clearState'](source, payload)
end)

exports.nexa_api:RegisterServerCallback(CALLBACKS.resources, function(source, payload)
    local rejected = rejectRequest(source, CALLBACKS.resources)

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateResourceStatePayload(payload)
    local invalid = validateOrFail(valid, code, 'Ungueltige Resource-State-Anfrage.')

    if invalid ~= nil then
        return invalid
    end

    return exports.nexa_worldstates['worldstates.getResourceStates'](source, payload)
end)
