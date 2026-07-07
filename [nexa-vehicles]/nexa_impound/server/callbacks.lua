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

local function normalizeVehicleId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeText(value, fallback, maxLength)
    local text = NexaImpoundLimitText(value or fallback, maxLength)

    if text == '' then
        return nil
    end

    return text
end

local function normalizeFee(value, fallback)
    local fee = tonumber(value)

    if fee == nil then
        fee = fallback
    end

    if fee == nil or fee < 0 or fee > NexaImpoundServerConfig.maxFee or math.floor(fee) ~= fee then
        return nil
    end

    return fee
end

local function normalizeAccountReference(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local accountId = tonumber(payload.accountId)

    if accountId ~= nil and accountId > 0 then
        return {
            accountId = math.floor(accountId)
        }
    end

    local accountNumber = NexaImpoundTrim(payload.accountNumber)

    if accountNumber ~= '' then
        return {
            accountNumber = accountNumber
        }
    end

    return nil
end

local function getLocation(locationId)
    local normalized = normalizeText(locationId, nil, NexaImpoundServerConfig.maxLocationLength)

    if normalized == nil then
        return nil
    end

    for _, location in ipairs(NexaImpoundServerConfig.locations or {}) do
        if location.id == normalized and location.isActive == true then
            return location
        end
    end

    return nil
end

local function callVehicleApi(exportName, source, payload)
    if GetResourceState('nexa_api') ~= 'started' then
        return NexaImpoundBuildResponse(false, 'RESOURCE_UNAVAILABLE', 'Fahrzeug-API ist nicht verfuegbar.', nil, nil)
    end

    return exports.nexa_api[exportName](source, payload or {})
end

local function auditImpound(action, source, metadata)
    if GetResourceState('nexa_audit') == 'started' then
        exports.nexa_audit:write({
            eventType = 'vehicle',
            severity = 'info',
            action = action,
            resourceName = NexaImpoundConstants.resourceName,
            metadata = metadata or {
                source = source
            }
        })
    end

    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info(NexaImpoundConstants.resourceName, 'Verwahrungsaktion wurde verarbeitet.', metadata or {
            source = source
        })
    end
end

lib.callback.register(NexaImpoundConfig.callbacks.status, function(source, payload)
    if not checkRequest(source, NexaImpoundServerConfig.callbackRateLimits.status) then
        return NexaImpoundBuildResponse(false, 'RATE_LIMITED', NexaImpoundLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local vehicleId = normalizeVehicleId(payload.vehicleId)

    if vehicleId == nil then
        return NexaImpoundBuildResponse(false, 'INVALID_INPUT', NexaImpoundLocale.invalid, nil, nil)
    end

    return callVehicleApi('vehicle.getImpoundStatus', source, {
        vehicleId = vehicleId
    })
end)

lib.callback.register(NexaImpoundConfig.callbacks.impound, function(source, payload)
    if not checkRequest(source, NexaImpoundServerConfig.callbackRateLimits.impound) then
        return NexaImpoundBuildResponse(false, 'RATE_LIMITED', NexaImpoundLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local vehicleId = normalizeVehicleId(payload.vehicleId)
    local location = getLocation(payload.locationId or 'mission_row_impound')
    local reason = normalizeText(payload.reason, 'vehicle.impound', NexaImpoundServerConfig.maxReasonLength)

    if vehicleId == nil or location == nil or reason == nil then
        return NexaImpoundBuildResponse(false, 'INVALID_INPUT', NexaImpoundLocale.invalid, nil, nil)
    end

    local fee = normalizeFee(location.fee, NexaImpoundServerConfig.defaultFee)

    if fee == nil then
        return NexaImpoundBuildResponse(false, 'INVALID_INPUT', NexaImpoundLocale.invalid, nil, nil)
    end

    if not NexaImpoundAcquireVehicleLock(vehicleId, source) then
        return NexaImpoundBuildResponse(false, 'CONFLICT', NexaImpoundLocale.conflict, nil, nil)
    end

    local ok, result = pcall(function()
        return callVehicleApi('vehicle.impound', source, {
            vehicleId = vehicleId,
            fee = fee,
            reason = reason,
            location = location.releaseGarageName or NexaImpoundServerConfig.defaultReleaseGarage
        })
    end)

    NexaImpoundReleaseVehicleLock(vehicleId, source)

    if not ok then
        return NexaImpoundBuildResponse(false, 'INTERNAL_ERROR', 'Fahrzeug konnte nicht verwahrt werden.', nil, nil)
    end

    if type(result) == 'table' and result.success == true then
        auditImpound('impound.create', source, {
            source = source,
            vehicleId = vehicleId,
            fee = fee,
            location = location.id
        })
    end

    return result
end)

lib.callback.register(NexaImpoundConfig.callbacks.release, function(source, payload)
    if not checkRequest(source, NexaImpoundServerConfig.callbackRateLimits.release) then
        return NexaImpoundBuildResponse(false, 'RATE_LIMITED', NexaImpoundLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local vehicleId = normalizeVehicleId(payload.vehicleId)
    local fee = normalizeFee(payload.fee, nil)
    local accountReference = normalizeAccountReference(payload)
    local garageName = normalizeText(payload.garageName, NexaImpoundServerConfig.defaultReleaseGarage, NexaImpoundServerConfig.maxLocationLength)

    if vehicleId == nil or fee == nil or garageName == nil then
        return NexaImpoundBuildResponse(false, 'INVALID_INPUT', NexaImpoundLocale.invalid, nil, nil)
    end

    if fee > 0 and accountReference == nil then
        return NexaImpoundBuildResponse(false, 'INVALID_INPUT', 'Fuer die Freigabe wird ein Konto benoetigt.', nil, nil)
    end

    if not NexaImpoundAcquireVehicleLock(vehicleId, source) then
        return NexaImpoundBuildResponse(false, 'CONFLICT', NexaImpoundLocale.conflict, nil, nil)
    end

    local ok, result = pcall(function()
        return callVehicleApi('vehicle.releaseImpound', source, {
            vehicleId = vehicleId,
            fee = fee,
            accountId = accountReference and accountReference.accountId or nil,
            accountNumber = accountReference and accountReference.accountNumber or nil,
            garageName = garageName,
            reason = 'vehicle.impound.release'
        })
    end)

    NexaImpoundReleaseVehicleLock(vehicleId, source)

    if not ok then
        return NexaImpoundBuildResponse(false, 'INTERNAL_ERROR', 'Fahrzeug konnte nicht freigegeben werden.', nil, nil)
    end

    if type(result) == 'table' and result.success == true then
        auditImpound('impound.release', source, {
            source = source,
            vehicleId = vehicleId,
            fee = fee
        })
    end

    return result
end)
