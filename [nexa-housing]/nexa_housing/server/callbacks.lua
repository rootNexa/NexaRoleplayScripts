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

local function normalizeLimit(value)
    local number = tonumber(value) or NexaHousingServerConfig.maxListLimit

    if number < 1 then
        return NexaHousingServerConfig.maxListLimit
    end

    return math.min(math.floor(number), NexaHousingServerConfig.maxListLimit)
end

local function normalizeAccountReference(payload)
    if type(payload) ~= 'table' then
        return nil
    end

    local accountId = NexaHousingNormalizeId(payload.accountId)

    if accountId ~= nil then
        return {
            accountId = accountId
        }
    end

    local accountNumber = NexaHousingTrim(payload.accountNumber)

    if accountNumber ~= '' and #accountNumber <= 32 then
        return {
            accountNumber = accountNumber
        }
    end

    return nil
end

local function callPropertyApi(exportName, source, payload)
    if GetResourceState('nexa_api') ~= 'started' then
        return NexaHousingBuildResponse(false, 'RESOURCE_UNAVAILABLE', NexaHousingLocale.unavailable, nil, nil)
    end

    return exports.nexa_api[exportName](source, payload or {})
end

local function auditHousing(action, source, metadata)
    metadata = metadata or {
        source = source
    }

    if GetResourceState('nexa_audit') == 'started' then
        exports.nexa_audit:write({
            eventType = 'property',
            severity = 'info',
            action = action,
            resourceName = NexaHousingConstants.resourceName,
            metadata = metadata
        })
    end

    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info(NexaHousingConstants.resourceName, 'Immobilienaktion wurde verarbeitet.', metadata)
    end
end

lib.callback.register(NexaHousingConfig.callbacks.list, function(source, payload)
    if not checkRequest(source, NexaHousingServerConfig.callbackRateLimits.list) then
        return NexaHousingBuildResponse(false, 'RATE_LIMITED', NexaHousingLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}

    return callPropertyApi('property.list', source, {
        status = payload.status,
        limit = normalizeLimit(payload.limit)
    })
end)

lib.callback.register(NexaHousingConfig.callbacks.accessible, function(source, payload)
    if not checkRequest(source, NexaHousingServerConfig.callbackRateLimits.accessible) then
        return NexaHousingBuildResponse(false, 'RATE_LIMITED', NexaHousingLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}

    return callPropertyApi('property.listAccessible', source, {
        limit = normalizeLimit(payload.limit)
    })
end)

lib.callback.register(NexaHousingConfig.callbacks.status, function(source, payload)
    if not checkRequest(source, NexaHousingServerConfig.callbackRateLimits.status) then
        return NexaHousingBuildResponse(false, 'RATE_LIMITED', NexaHousingLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local propertyUnitId = NexaHousingNormalizeId(payload.propertyUnitId, NexaHousingServerConfig.maxPropertyUnitId)

    if propertyUnitId == nil then
        return NexaHousingBuildResponse(false, 'INVALID_INPUT', NexaHousingLocale.invalid, nil, nil)
    end

    return callPropertyApi('property.getStatus', source, {
        propertyUnitId = propertyUnitId
    })
end)

lib.callback.register(NexaHousingConfig.callbacks.access, function(source, payload)
    if not checkRequest(source, NexaHousingServerConfig.callbackRateLimits.access) then
        return NexaHousingBuildResponse(false, 'RATE_LIMITED', NexaHousingLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local propertyUnitId = NexaHousingNormalizeId(payload.propertyUnitId, NexaHousingServerConfig.maxPropertyUnitId)

    if propertyUnitId == nil then
        return NexaHousingBuildResponse(false, 'INVALID_INPUT', NexaHousingLocale.invalid, nil, nil)
    end

    return callPropertyApi('property.hasAccess', source, {
        propertyUnitId = propertyUnitId
    })
end)

local function processPaidAction(source, payload, action, apiExport)
    payload = type(payload) == 'table' and payload or {}
    local propertyUnitId = NexaHousingNormalizeId(payload.propertyUnitId, NexaHousingServerConfig.maxPropertyUnitId)
    local accountReference = normalizeAccountReference(payload)

    if propertyUnitId == nil or accountReference == nil then
        return NexaHousingBuildResponse(false, 'INVALID_INPUT', NexaHousingLocale.invalid, nil, nil)
    end

    if not NexaHousingAcquireLock(source, action, propertyUnitId) then
        return NexaHousingBuildResponse(false, 'CONFLICT', NexaHousingLocale.conflict, nil, nil)
    end

    local ok, result = pcall(function()
        return callPropertyApi(apiExport, source, {
            propertyUnitId = propertyUnitId,
            accountId = accountReference.accountId,
            accountNumber = accountReference.accountNumber
        })
    end)

    NexaHousingReleaseLock(source, action, propertyUnitId)

    if not ok then
        return NexaHousingBuildResponse(false, 'INTERNAL_ERROR', 'Immobilienaktion konnte nicht abgeschlossen werden.', nil, nil)
    end

    if type(result) == 'table' and result.success == true then
        auditHousing('housing.' .. action, source, {
            source = source,
            propertyUnitId = propertyUnitId,
            propertyTransactionId = result.data and result.data.propertyTransactionId or nil
        })
    end

    return result
end

lib.callback.register(NexaHousingConfig.callbacks.purchase, function(source, payload)
    if not checkRequest(source, NexaHousingServerConfig.callbackRateLimits.purchase) then
        return NexaHousingBuildResponse(false, 'RATE_LIMITED', NexaHousingLocale.rateLimited, nil, nil)
    end

    return processPaidAction(source, payload, 'purchase', 'property.purchase')
end)

lib.callback.register(NexaHousingConfig.callbacks.rent, function(source, payload)
    if not checkRequest(source, NexaHousingServerConfig.callbackRateLimits.rent) then
        return NexaHousingBuildResponse(false, 'RATE_LIMITED', NexaHousingLocale.rateLimited, nil, nil)
    end

    return processPaidAction(source, payload, 'rent', 'property.rent')
end)

lib.callback.register(NexaHousingConfig.callbacks.grantAccess, function(source, payload)
    if not checkRequest(source, NexaHousingServerConfig.callbackRateLimits.grantAccess) then
        return NexaHousingBuildResponse(false, 'RATE_LIMITED', NexaHousingLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local propertyUnitId = NexaHousingNormalizeId(payload.propertyUnitId, NexaHousingServerConfig.maxPropertyUnitId)
    local characterId = NexaHousingNormalizeId(payload.characterId, NexaHousingServerConfig.maxCharacterId)
    local accessType = NexaHousingTrim(payload.accessType or 'guest')
    local durationMinutes = tonumber(payload.durationMinutes)
    local expiresAt = NexaHousingTrim(payload.expiresAt)

    if propertyUnitId == nil or characterId == nil or not NexaHousingServerConfig.allowedAccessTypes[accessType] then
        return NexaHousingBuildResponse(false, 'INVALID_INPUT', NexaHousingLocale.invalid, nil, nil)
    end

    return callPropertyApi('property.grantAccess', source, {
        propertyUnitId = propertyUnitId,
        characterId = characterId,
        accessType = accessType,
        durationMinutes = durationMinutes,
        expiresAt = expiresAt ~= '' and expiresAt or nil
    })
end)

lib.callback.register(NexaHousingConfig.callbacks.listAccess, function(source, payload)
    if not checkRequest(source, NexaHousingServerConfig.callbackRateLimits.listAccess) then
        return NexaHousingBuildResponse(false, 'RATE_LIMITED', NexaHousingLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local propertyUnitId = NexaHousingNormalizeId(payload.propertyUnitId, NexaHousingServerConfig.maxPropertyUnitId)

    if propertyUnitId == nil then
        return NexaHousingBuildResponse(false, 'INVALID_INPUT', NexaHousingLocale.invalid, nil, nil)
    end

    return callPropertyApi('property.listAccess', source, {
        propertyUnitId = propertyUnitId
    })
end)

lib.callback.register(NexaHousingConfig.callbacks.revokeAccess, function(source, payload)
    if not checkRequest(source, NexaHousingServerConfig.callbackRateLimits.revokeAccess) then
        return NexaHousingBuildResponse(false, 'RATE_LIMITED', NexaHousingLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local propertyUnitId = NexaHousingNormalizeId(payload.propertyUnitId, NexaHousingServerConfig.maxPropertyUnitId)
    local characterId = NexaHousingNormalizeId(payload.characterId, NexaHousingServerConfig.maxCharacterId)
    local reason = NexaHousingTrim(payload.reason)

    if propertyUnitId == nil or characterId == nil or reason == '' or #reason > 128 then
        return NexaHousingBuildResponse(false, 'INVALID_INPUT', NexaHousingLocale.invalid, nil, nil)
    end

    local result = callPropertyApi('property.revokeAccess', source, {
        propertyUnitId = propertyUnitId,
        characterId = characterId,
        reason = reason
    })

    if type(result) == 'table' and result.success == true then
        auditHousing('housing.access.revoke', source, {
            source = source,
            propertyUnitId = propertyUnitId,
            characterId = characterId
        })
    end

    return result
end)

local function normalizeStoragePayload(payload)
    payload = type(payload) == 'table' and payload or {}

    local propertyUnitId = NexaHousingNormalizeId(payload.propertyUnitId, NexaHousingServerConfig.maxPropertyUnitId)
    local storageType = NexaHousingTrim(payload.storageType or 'private')

    if propertyUnitId == nil or not NexaHousingServerConfig.allowedStorageTypes[storageType] then
        return nil
    end

    return {
        propertyUnitId = propertyUnitId,
        storageType = storageType
    }
end

lib.callback.register(NexaHousingConfig.callbacks.ensureStorage, function(source, payload)
    if not checkRequest(source, NexaHousingServerConfig.callbackRateLimits.ensureStorage) then
        return NexaHousingBuildResponse(false, 'RATE_LIMITED', NexaHousingLocale.rateLimited, nil, nil)
    end

    local storagePayload = normalizeStoragePayload(payload)

    if storagePayload == nil then
        return NexaHousingBuildResponse(false, 'INVALID_INPUT', NexaHousingLocale.invalid, nil, nil)
    end

    return callPropertyApi('property.ensureStorage', source, storagePayload)
end)

lib.callback.register(NexaHousingConfig.callbacks.openStorage, function(source, payload)
    if not checkRequest(source, NexaHousingServerConfig.callbackRateLimits.openStorage) then
        return NexaHousingBuildResponse(false, 'RATE_LIMITED', NexaHousingLocale.rateLimited, nil, nil)
    end

    local storagePayload = normalizeStoragePayload(payload)

    if storagePayload == nil then
        return NexaHousingBuildResponse(false, 'INVALID_INPUT', NexaHousingLocale.invalid, nil, nil)
    end

    local result = callPropertyApi('property.openStorage', source, storagePayload)

    if type(result) == 'table' and result.success == true then
        auditHousing('housing.storage.open', source, {
            source = source,
            propertyUnitId = storagePayload.propertyUnitId,
            storageType = storagePayload.storageType,
            storageId = result.data and result.data.storage and result.data.storage.id or nil
        })
    end

    return result
end)
