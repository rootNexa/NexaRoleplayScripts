local function checkRequest(source, eventName)
    if not exports.nexa_security:validateSource(source) then
        return exports.nexa_api:buildResponse(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return exports.nexa_api:buildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil, nil)
    end

    return nil
end

lib.callback.register('nexa:jobs_core:cb:listJobs', function(source)
    local rejected = checkRequest(source, 'nexa:jobs_core:cb:listJobs')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_api['job.list']()
end)

lib.callback.register('nexa:jobs_core:cb:getCurrentJob', function(source, payload)
    local rejected = checkRequest(source, 'nexa:jobs_core:cb:getCurrentJob')

    if rejected ~= nil then
        return rejected
    end

    return exports.nexa_api['job.getCharacter'](source, payload or {})
end)

lib.callback.register('nexa:jobs_core:cb:assignJob', function(source, payload)
    local rejected = checkRequest(source, 'nexa:jobs_core:cb:assignJob')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateAssignJobPayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Jobdaten.', nil, nil, nil)
    end

    return exports.nexa_api['job.assign'](source, payload)
end)

lib.callback.register('nexa:jobs_core:cb:startDuty', function(source, payload)
    local rejected = checkRequest(source, 'nexa:jobs_core:cb:startDuty')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateJobReferencePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Dienstdaten.', nil, nil, nil)
    end

    return exports.nexa_api['job.startDuty'](source, payload or {})
end)

lib.callback.register('nexa:jobs_core:cb:endDuty', function(source, payload)
    local rejected = checkRequest(source, 'nexa:jobs_core:cb:endDuty')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateJobReferencePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Dienstdaten.', nil, nil, nil)
    end

    return exports.nexa_api['job.endDuty'](source, payload or {})
end)

lib.callback.register('nexa:jobs_core:cb:requestSalary', function(source, payload)
    local rejected = checkRequest(source, 'nexa:jobs_core:cb:requestSalary')

    if rejected ~= nil then
        return rejected
    end

    local valid, code = validateJobReferencePayload(payload)

    if not valid then
        return exports.nexa_api:buildResponse(false, code, 'Ungueltige Gehaltsdaten.', nil, nil, nil)
    end

    return exports.nexa_api['job.paySalary'](source, payload or {})
end)
