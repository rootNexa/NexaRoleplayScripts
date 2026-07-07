local function rejectRequest(source, eventName)
    if not exports.nexa_security:validateSource(source) then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return exports.nexa_api:buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil)
    end

    return nil
end

lib.callback.register('nexa:maps:cb:list', function(source, payload)
    local rejected = rejectRequest(source, 'nexa:maps:cb:list')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_maps['maps.list'](source, payload or {})
end)

lib.callback.register('nexa:maps:cb:get', function(source, mapId)
    local rejected = rejectRequest(source, 'nexa:maps:cb:get')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_maps['maps.get'](source, mapId)
end)
