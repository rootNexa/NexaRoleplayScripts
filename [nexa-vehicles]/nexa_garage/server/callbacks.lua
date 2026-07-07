local function checkRequest(source, callbackName)
    if GetResourceState('nexa_security') ~= 'started' then
        return true
    end

    if not exports.nexa_security:validateSource(source) then
        return false
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, callbackName)

    return rateLimit ~= nil and rateLimit.success == true
end

local function normalizeGarageName(value)
    return NexaGarageLimitText(value or NexaGarageServerConfig.defaultGarageName, NexaGarageServerConfig.maxGarageNameLength)
end

local function normalizeVehicleId(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local value = tonumber(payload.vehicleId)

    if value == nil or value <= 0 then
        return nil
    end

    return math.floor(value)
end

local function callVehicleApi(exportName, source, payload)
    if GetResourceState('nexa_api') ~= 'started' then
        return NexaGarageBuildResponse(false, 'RESOURCE_UNAVAILABLE', 'Fahrzeug-API ist nicht verfuegbar.', nil, nil)
    end

    return exports.nexa_api[exportName](source, payload or {})
end

local function auditGarage(action, source, metadata)
    if GetResourceState('nexa_audit') == 'started' then
        exports.nexa_audit:write({
            eventType = 'vehicle',
            severity = 'info',
            action = action,
            resourceName = 'nexa_garage',
            metadata = metadata or {
                source = source
            }
        })
    end

    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info('nexa_garage', 'Garagenaktion wurde verarbeitet.', metadata or {
            source = source
        })
    end
end

lib.callback.register(NexaGarageConfig.callbacks.list, function(source, payload)
    if not checkRequest(source, NexaGarageServerConfig.callbackRateLimits.list) then
        return NexaGarageBuildResponse(false, 'RATE_LIMITED', NexaGarageLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local garageName = normalizeGarageName(payload.garageName)

    return callVehicleApi('vehicle.listGarage', source, {
        garageName = garageName,
        limit = payload.limit
    })
end)

lib.callback.register(NexaGarageConfig.callbacks.store, function(source, payload)
    if not checkRequest(source, NexaGarageServerConfig.callbackRateLimits.store) then
        return NexaGarageBuildResponse(false, 'RATE_LIMITED', NexaGarageLocale.rateLimited, nil, nil)
    end

    local vehicleId = normalizeVehicleId(payload)

    if vehicleId == nil then
        return NexaGarageBuildResponse(false, 'INVALID_INPUT', NexaGarageLocale.invalid, nil, nil)
    end

    if not NexaGarageAcquireLock(vehicleId, source) then
        return NexaGarageBuildResponse(false, 'CONFLICT', NexaGarageLocale.conflict, nil, nil)
    end

    local ok, result = pcall(function()
        return callVehicleApi('vehicle.storeGarage', source, {
            vehicleId = vehicleId,
            garageName = normalizeGarageName(payload.garageName)
        })
    end)

    NexaGarageReleaseLock(vehicleId, source)

    if not ok then
        return NexaGarageBuildResponse(false, 'INTERNAL_ERROR', 'Garagenaktion konnte nicht abgeschlossen werden.', nil, nil)
    end

    if type(result) == 'table' and result.success == true then
        auditGarage('garage.store', source, {
            source = source,
            vehicleId = vehicleId
        })
    end

    return result
end)

lib.callback.register(NexaGarageConfig.callbacks.retrieve, function(source, payload)
    if not checkRequest(source, NexaGarageServerConfig.callbackRateLimits.retrieve) then
        return NexaGarageBuildResponse(false, 'RATE_LIMITED', NexaGarageLocale.rateLimited, nil, nil)
    end

    local vehicleId = normalizeVehicleId(payload)

    if vehicleId == nil then
        return NexaGarageBuildResponse(false, 'INVALID_INPUT', NexaGarageLocale.invalid, nil, nil)
    end

    if not NexaGarageAcquireLock(vehicleId, source) then
        return NexaGarageBuildResponse(false, 'CONFLICT', NexaGarageLocale.conflict, nil, nil)
    end

    local ok, result = pcall(function()
        return callVehicleApi('vehicle.retrieveGarage', source, {
            vehicleId = vehicleId,
            garageName = normalizeGarageName(payload.garageName)
        })
    end)

    NexaGarageReleaseLock(vehicleId, source)

    if not ok then
        return NexaGarageBuildResponse(false, 'INTERNAL_ERROR', 'Garagenaktion konnte nicht abgeschlossen werden.', nil, nil)
    end

    if type(result) == 'table' and result.success == true then
        auditGarage('garage.retrieve', source, {
            source = source,
            vehicleId = vehicleId
        })
    end

    return result
end)
