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

local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeReason(value, fallback)
    local text = NexaVehicleKeysLimitText(value or fallback, NexaVehicleKeysServerConfig.maxReasonLength)

    if text == '' then
        return fallback
    end

    return text
end

local function normalizeDuration(value)
    local duration = tonumber(value) or NexaVehicleKeysServerConfig.defaultTemporaryMinutes
    duration = math.floor(duration)

    if duration < 1 or duration > NexaVehicleKeysServerConfig.maxTemporaryMinutes then
        return nil
    end

    return duration
end

local function callVehicleApi(exportName, source, payload)
    if GetResourceState('nexa_api') ~= 'started' then
        return NexaVehicleKeysBuildResponse(false, 'RESOURCE_UNAVAILABLE', 'Fahrzeug-API ist nicht verfuegbar.', nil, nil)
    end

    return exports.nexa_api[exportName](source, payload or {})
end

local function auditVehicleKeys(action, source, metadata)
    if GetResourceState('nexa_audit') == 'started' then
        exports.nexa_audit:write({
            eventType = 'vehicle',
            severity = 'info',
            action = action,
            resourceName = 'nexa_vehiclekeys',
            metadata = metadata or {
                source = source
            }
        })
    end

    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info('nexa_vehiclekeys', 'Fahrzeugschluesselaktion wurde verarbeitet.', metadata or {
            source = source
        })
    end
end

lib.callback.register(NexaVehicleKeysConfig.callbacks.hasKey, function(source, payload)
    if not checkRequest(source, NexaVehicleKeysServerConfig.callbackRateLimits.hasKey) then
        return NexaVehicleKeysBuildResponse(false, 'RATE_LIMITED', NexaVehicleKeysLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local vehicleId = normalizeId(payload.vehicleId)

    if vehicleId == nil then
        return NexaVehicleKeysBuildResponse(false, 'INVALID_INPUT', NexaVehicleKeysLocale.invalid, nil, nil)
    end

    return callVehicleApi('vehicle.hasKey', source, {
        vehicleId = vehicleId
    })
end)

lib.callback.register(NexaVehicleKeysConfig.callbacks.grantKey, function(source, payload)
    if not checkRequest(source, NexaVehicleKeysServerConfig.callbackRateLimits.grantKey) then
        return NexaVehicleKeysBuildResponse(false, 'RATE_LIMITED', NexaVehicleKeysLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local vehicleId = normalizeId(payload.vehicleId)
    local characterId = normalizeId(payload.characterId)

    if vehicleId == nil or characterId == nil then
        return NexaVehicleKeysBuildResponse(false, 'INVALID_INPUT', NexaVehicleKeysLocale.invalid, nil, nil)
    end

    local result = callVehicleApi('vehicle.grantKey', source, {
        vehicleId = vehicleId,
        characterId = characterId,
        keyType = 'shared',
        reason = normalizeReason(payload.reason, 'vehicle.key.grant')
    })

    if type(result) == 'table' and result.success == true then
        auditVehicleKeys('vehiclekeys.grant', source, {
            source = source,
            vehicleId = vehicleId,
            characterId = characterId
        })
    end

    return result
end)

lib.callback.register(NexaVehicleKeysConfig.callbacks.grantTemporaryKey, function(source, payload)
    if not checkRequest(source, NexaVehicleKeysServerConfig.callbackRateLimits.grantTemporaryKey) then
        return NexaVehicleKeysBuildResponse(false, 'RATE_LIMITED', NexaVehicleKeysLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local vehicleId = normalizeId(payload.vehicleId)
    local characterId = normalizeId(payload.characterId)
    local duration = normalizeDuration(payload.durationMinutes)

    if vehicleId == nil or characterId == nil or duration == nil then
        return NexaVehicleKeysBuildResponse(false, 'INVALID_INPUT', NexaVehicleKeysLocale.invalid, nil, nil)
    end

    local result = callVehicleApi('vehicle.grantKey', source, {
        vehicleId = vehicleId,
        characterId = characterId,
        keyType = 'temporary',
        durationMinutes = duration,
        reason = normalizeReason(payload.reason, 'vehicle.key.grantTemporary')
    })

    if type(result) == 'table' and result.success == true then
        auditVehicleKeys('vehiclekeys.grantTemporary', source, {
            source = source,
            vehicleId = vehicleId,
            characterId = characterId,
            durationMinutes = duration
        })
    end

    return result
end)

lib.callback.register(NexaVehicleKeysConfig.callbacks.revokeKey, function(source, payload)
    if not checkRequest(source, NexaVehicleKeysServerConfig.callbackRateLimits.revokeKey) then
        return NexaVehicleKeysBuildResponse(false, 'RATE_LIMITED', NexaVehicleKeysLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local vehicleId = normalizeId(payload.vehicleId)
    local characterId = normalizeId(payload.characterId)
    local keyType = payload.keyType == 'temporary' and 'temporary' or 'shared'

    if vehicleId == nil or characterId == nil then
        return NexaVehicleKeysBuildResponse(false, 'INVALID_INPUT', NexaVehicleKeysLocale.invalid, nil, nil)
    end

    local result = callVehicleApi('vehicle.revokeKey', source, {
        vehicleId = vehicleId,
        characterId = characterId,
        keyType = keyType,
        reason = normalizeReason(payload.reason, 'vehicle.key.revoke')
    })

    if type(result) == 'table' and result.success == true then
        auditVehicleKeys('vehiclekeys.revoke', source, {
            source = source,
            vehicleId = vehicleId,
            characterId = characterId,
            keyType = keyType
        })
    end

    return result
end)

lib.callback.register(NexaVehicleKeysConfig.callbacks.toggleLock, function(source, payload)
    if not checkRequest(source, NexaVehicleKeysServerConfig.callbackRateLimits.toggleLock) then
        return NexaVehicleKeysBuildResponse(false, 'RATE_LIMITED', NexaVehicleKeysLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local vehicleId = normalizeId(payload.vehicleId)

    if vehicleId == nil then
        return NexaVehicleKeysBuildResponse(false, 'INVALID_INPUT', NexaVehicleKeysLocale.invalid, nil, nil)
    end

    return callVehicleApi('vehicle.toggleLock', source, {
        vehicleId = vehicleId
    })
end)
