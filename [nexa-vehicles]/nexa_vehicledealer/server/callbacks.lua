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

local function normalizeId(value, maxLength)
    local text = NexaVehicleDealerLimitText(value, maxLength)

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

    local accountNumber = NexaVehicleDealerTrim(payload.accountNumber)

    if accountNumber ~= '' then
        return {
            accountNumber = accountNumber
        }
    end

    return nil
end

local function sanitizeCatalogItem(dealer, item)
    return {
        id = item.id,
        model = item.model,
        label = item.label,
        vehicleType = item.vehicleType or 'car',
        price = item.price,
        garageName = item.garageName or dealer.garageName or NexaVehicleDealerServerConfig.defaultGarageName
    }
end

local function getDealer(dealerId)
    for _, dealer in ipairs(NexaVehicleDealerServerConfig.dealers or {}) do
        if dealer.id == dealerId and dealer.isActive == true then
            return dealer
        end
    end

    return nil
end

local function getCatalogItem(dealerId, catalogId)
    local dealer = getDealer(dealerId)

    if dealer == nil then
        return nil, nil
    end

    for _, item in ipairs(dealer.catalog or {}) do
        if item.id == catalogId then
            return dealer, sanitizeCatalogItem(dealer, item)
        end
    end

    return dealer, nil
end

local function listCatalog(dealerId)
    local dealer = getDealer(dealerId)

    if dealer == nil then
        return nil
    end

    local catalog = {}
    local maxItems = NexaVehicleDealerServerConfig.maxCatalogItems

    for index, item in ipairs(dealer.catalog or {}) do
        if index > maxItems then
            break
        end

        catalog[#catalog + 1] = sanitizeCatalogItem(dealer, item)
    end

    return {
        dealer = {
            id = dealer.id,
            label = dealer.label,
            garageName = dealer.garageName or NexaVehicleDealerServerConfig.defaultGarageName
        },
        catalog = catalog
    }
end

local function callVehicleApi(exportName, source, payload)
    if GetResourceState('nexa_api') ~= 'started' then
        return NexaVehicleDealerBuildResponse(false, 'RESOURCE_UNAVAILABLE', 'Fahrzeug-API ist nicht verfuegbar.', nil, nil)
    end

    return exports.nexa_api[exportName](source, payload or {})
end

local function auditDealer(action, source, metadata)
    if GetResourceState('nexa_audit') == 'started' then
        exports.nexa_audit:write({
            eventType = 'vehicle',
            severity = 'info',
            action = action,
            resourceName = NexaVehicleDealerConstants.resourceName,
            metadata = metadata or {
                source = source
            }
        })
    end

    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info(NexaVehicleDealerConstants.resourceName, 'Fahrzeughaendleraktion wurde verarbeitet.', metadata or {
            source = source
        })
    end
end

lib.callback.register(NexaVehicleDealerConfig.callbacks.catalog, function(source, payload)
    if not checkRequest(source, NexaVehicleDealerServerConfig.callbackRateLimits.catalog) then
        return NexaVehicleDealerBuildResponse(false, 'RATE_LIMITED', NexaVehicleDealerLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local dealerId = normalizeId(payload.dealerId or 'premium_deluxe', NexaVehicleDealerServerConfig.maxDealerIdLength)

    if dealerId == nil then
        return NexaVehicleDealerBuildResponse(false, 'INVALID_INPUT', NexaVehicleDealerLocale.invalid, nil, nil)
    end

    local catalog = listCatalog(dealerId)

    if catalog == nil then
        return NexaVehicleDealerBuildResponse(false, 'NOT_FOUND', 'Fahrzeughaendler wurde nicht gefunden.', nil, nil)
    end

    return NexaVehicleDealerBuildResponse(true, 'OK', 'Fahrzeugkatalog wurde geladen.', catalog, nil)
end)

lib.callback.register(NexaVehicleDealerConfig.callbacks.purchase, function(source, payload)
    if not checkRequest(source, NexaVehicleDealerServerConfig.callbackRateLimits.purchase) then
        return NexaVehicleDealerBuildResponse(false, 'RATE_LIMITED', NexaVehicleDealerLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local dealerId = normalizeId(payload.dealerId, NexaVehicleDealerServerConfig.maxDealerIdLength)
    local catalogId = normalizeId(payload.catalogId, NexaVehicleDealerServerConfig.maxCatalogIdLength)
    local accountReference = normalizeAccountReference(payload)

    if dealerId == nil or catalogId == nil or accountReference == nil then
        return NexaVehicleDealerBuildResponse(false, 'INVALID_INPUT', NexaVehicleDealerLocale.invalid, nil, nil)
    end

    local _, catalogItem = getCatalogItem(dealerId, catalogId)

    if catalogItem == nil then
        return NexaVehicleDealerBuildResponse(false, 'NOT_FOUND', 'Fahrzeug wurde im Katalog nicht gefunden.', nil, nil)
    end

    if not NexaVehicleDealerAcquirePurchaseLock(source, dealerId, catalogId) then
        return NexaVehicleDealerBuildResponse(false, 'CONFLICT', NexaVehicleDealerLocale.conflict, nil, nil)
    end

    local ok, result = pcall(function()
        return callVehicleApi('vehicle.purchaseDealer', source, {
            dealerId = dealerId,
            catalogItem = catalogItem,
            accountId = accountReference.accountId,
            accountNumber = accountReference.accountNumber
        })
    end)

    NexaVehicleDealerReleasePurchaseLock(source, dealerId, catalogId)

    if not ok then
        return NexaVehicleDealerBuildResponse(false, 'INTERNAL_ERROR', 'Fahrzeugkauf konnte nicht abgeschlossen werden.', nil, nil)
    end

    if type(result) == 'table' and result.success == true then
        auditDealer('vehicledealer.purchase', source, {
            source = source,
            dealerId = dealerId,
            catalogId = catalogId,
            vehicleId = result.data and result.data.vehicle and result.data.vehicle.id or nil
        })
    end

    return result
end)

lib.callback.register(NexaVehicleDealerConfig.callbacks.prepareSale, function(source, payload)
    if not checkRequest(source, NexaVehicleDealerServerConfig.callbackRateLimits.prepareSale) then
        return NexaVehicleDealerBuildResponse(false, 'RATE_LIMITED', NexaVehicleDealerLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local vehicleId = normalizeVehicleId(payload.vehicleId)

    if vehicleId == nil then
        return NexaVehicleDealerBuildResponse(false, 'INVALID_INPUT', NexaVehicleDealerLocale.invalid, nil, nil)
    end

    return callVehicleApi('vehicle.prepareDealerSale', source, {
        vehicleId = vehicleId
    })
end)
