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

local function normalizeText(value, maxLength)
    local text = NexaFuelLimitText(value, maxLength)

    if text == '' then
        return nil
    end

    return text
end

local function normalizeVehicleId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizePositiveDecimal(value, maxValue)
    local number = tonumber(value)

    if number == nil or number <= 0 or number > maxValue then
        return nil
    end

    return math.floor(number * 100 + 0.5) / 100
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

    local accountNumber = NexaFuelTrim(payload.accountNumber)

    if accountNumber ~= '' then
        return {
            accountNumber = accountNumber
        }
    end

    return nil
end

local function getStation(stationId)
    for _, station in ipairs(NexaFuelServerConfig.stations or {}) do
        if station.id == stationId and station.isActive == true then
            return station
        end
    end

    return nil
end

local function isNearStation(source, station)
    if type(station) ~= 'table' or type(station.coords) ~= 'table' then
        return false
    end

    local ped = GetPlayerPed(source)

    if ped == nil or ped == 0 then
        return false
    end

    local coords = GetEntityCoords(ped)
    local dx = (coords.x or 0.0) - station.coords.x
    local dy = (coords.y or 0.0) - station.coords.y
    local dz = (coords.z or 0.0) - station.coords.z
    local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))

    return distance <= NexaFuelServerConfig.maxStationDistance
end

local function listStations()
    local stations = {}

    for index, station in ipairs(NexaFuelServerConfig.stations or {}) do
        if index > NexaFuelServerConfig.maxStations then
            break
        end

        if station.isActive == true then
            stations[#stations + 1] = {
                id = station.id,
                label = station.label,
                pricePerLiter = station.pricePerLiter or NexaFuelServerConfig.pricePerLiter,
                coords = station.coords
            }
        end
    end

    return stations
end

local function callVehicleApi(exportName, source, payload)
    if GetResourceState('nexa_api') ~= 'started' then
        return NexaFuelBuildResponse(false, 'RESOURCE_UNAVAILABLE', 'Fahrzeug-API ist nicht verfuegbar.', nil, nil)
    end

    return exports.nexa_api[exportName](source, payload or {})
end

local function auditFuel(action, source, metadata)
    if GetResourceState('nexa_audit') == 'started' then
        exports.nexa_audit:write({
            eventType = 'vehicle',
            severity = 'info',
            action = action,
            resourceName = NexaFuelConstants.resourceName,
            metadata = metadata or {
                source = source
            }
        })
    end

    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info(NexaFuelConstants.resourceName, 'Kraftstoffaktion wurde verarbeitet.', metadata or {
            source = source
        })
    end
end

lib.callback.register(NexaFuelConfig.callbacks.stations, function(source)
    if not checkRequest(source, NexaFuelServerConfig.callbackRateLimits.stations) then
        return NexaFuelBuildResponse(false, 'RATE_LIMITED', NexaFuelLocale.rateLimited, nil, nil)
    end

    return NexaFuelBuildResponse(true, 'OK', 'Tankstellen wurden geladen.', {
        stations = listStations()
    }, nil)
end)

lib.callback.register(NexaFuelConfig.callbacks.fuel, function(source, payload)
    if not checkRequest(source, NexaFuelServerConfig.callbackRateLimits.fuel) then
        return NexaFuelBuildResponse(false, 'RATE_LIMITED', NexaFuelLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local vehicleId = normalizeVehicleId(payload.vehicleId)

    if vehicleId == nil then
        return NexaFuelBuildResponse(false, 'INVALID_INPUT', NexaFuelLocale.invalid, nil, nil)
    end

    return callVehicleApi('vehicle.getFuel', source, {
        vehicleId = vehicleId
    })
end)

lib.callback.register(NexaFuelConfig.callbacks.purchase, function(source, payload)
    if not checkRequest(source, NexaFuelServerConfig.callbackRateLimits.purchase) then
        return NexaFuelBuildResponse(false, 'RATE_LIMITED', NexaFuelLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local stationId = normalizeText(payload.stationId, NexaFuelServerConfig.maxStationIdLength)
    local vehicleId = normalizeVehicleId(payload.vehicleId)
    local liters = normalizePositiveDecimal(payload.liters, NexaFuelServerConfig.maxFuelLiters)
    local accountReference = normalizeAccountReference(payload)

    if stationId == nil or vehicleId == nil or liters == nil or accountReference == nil then
        return NexaFuelBuildResponse(false, 'INVALID_INPUT', NexaFuelLocale.invalid, nil, nil)
    end

    local station = getStation(stationId)

    if station == nil then
        return NexaFuelBuildResponse(false, 'NOT_FOUND', 'Tankstelle wurde nicht gefunden.', nil, nil)
    end

    if not isNearStation(source, station) then
        return NexaFuelBuildResponse(false, 'DISTANCE_TOO_FAR', 'Du bist zu weit von der Tankstelle entfernt.', nil, nil)
    end

    if not NexaFuelAcquirePurchaseLock(source, stationId, vehicleId) then
        return NexaFuelBuildResponse(false, 'CONFLICT', NexaFuelLocale.conflict, nil, nil)
    end

    local pricePerLiter = station.pricePerLiter or NexaFuelServerConfig.pricePerLiter
    local ok, result = pcall(function()
        return callVehicleApi('vehicle.purchaseFuel', source, {
            stationId = stationId,
            vehicleId = vehicleId,
            liters = liters,
            pricePerLiter = pricePerLiter,
            accountId = accountReference.accountId,
            accountNumber = accountReference.accountNumber
        })
    end)

    NexaFuelReleasePurchaseLock(source, stationId, vehicleId)

    if not ok then
        return NexaFuelBuildResponse(false, 'INTERNAL_ERROR', 'Tankvorgang konnte nicht abgeschlossen werden.', nil, nil)
    end

    if type(result) == 'table' and result.success == true then
        auditFuel('fuel.purchase', source, {
            source = source,
            stationId = stationId,
            vehicleId = vehicleId,
            liters = result.data and result.data.fuel and result.data.fuel.liters or liters,
            amount = result.data and result.data.ledger and result.data.ledger.amount or nil
        })
    end

    return result
end)

lib.callback.register(NexaFuelConfig.callbacks.consumption, function(source, payload)
    if not checkRequest(source, NexaFuelServerConfig.callbackRateLimits.consumption) then
        return NexaFuelBuildResponse(false, 'RATE_LIMITED', NexaFuelLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local vehicleId = normalizeVehicleId(payload.vehicleId)
    local consumed = normalizePositiveDecimal(payload.consumed, NexaFuelServerConfig.maxConsumptionDelta)

    if vehicleId == nil or consumed == nil then
        return NexaFuelBuildResponse(false, 'INVALID_INPUT', NexaFuelLocale.invalid, nil, nil)
    end

    return callVehicleApi('vehicle.consumeFuel', source, {
        vehicleId = vehicleId,
        consumed = consumed
    })
end)
