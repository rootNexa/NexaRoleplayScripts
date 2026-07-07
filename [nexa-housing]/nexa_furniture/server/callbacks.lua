local activeLocks = {}

local function buildLockKey(source, action, propertyUnitId, furnitureId)
    return ('%s:%s:%s:%s'):format(source, action, propertyUnitId or 0, furnitureId or 0)
end

local function acquireLock(source, action, propertyUnitId, furnitureId)
    local key = buildLockKey(source, action, propertyUnitId, furnitureId)

    if activeLocks[key] then
        return false
    end

    activeLocks[key] = true

    return true
end

local function releaseLock(source, action, propertyUnitId, furnitureId)
    activeLocks[buildLockKey(source, action, propertyUnitId, furnitureId)] = nil
end

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

local function callPropertyApi(exportName, source, payload)
    if GetResourceState('nexa_api') ~= 'started' then
        return NexaFurnitureBuildResponse(false, 'RESOURCE_UNAVAILABLE', NexaFurnitureLocale.unavailable, nil, nil)
    end

    return exports.nexa_api[exportName](source, payload or {})
end

local function normalizeModel(value)
    local model = NexaFurnitureTrim(value)

    if model == '' or #model > NexaFurnitureServerConfig.maxModelLength or not model:match('^[%w_%-]+$') then
        return nil
    end

    return model
end

local function normalizeLabel(value, fallback)
    local label = NexaFurnitureTrim(value)

    if label == '' then
        label = fallback
    end

    if label == nil or label == '' or #label > NexaFurnitureServerConfig.maxLabelLength then
        return nil
    end

    return label
end

local function normalizeTransformPayload(payload, requireFurnitureId)
    payload = type(payload) == 'table' and payload or {}

    local propertyUnitId = NexaFurnitureNormalizeId(payload.propertyUnitId, NexaFurnitureServerConfig.maxPropertyUnitId)
    local furnitureId = requireFurnitureId and NexaFurnitureNormalizeId(payload.furnitureId, NexaFurnitureServerConfig.maxFurnitureId) or nil
    local model = normalizeModel(payload.model)
    local label = normalizeLabel(payload.label, model)
    local position = NexaFurnitureNormalizeVector(payload.position)
    local rotation = NexaFurnitureNormalizeVector(payload.rotation)

    if propertyUnitId == nil or model == nil or label == nil or position == nil or rotation == nil then
        return nil
    end

    if requireFurnitureId and furnitureId == nil then
        return nil
    end

    return {
        propertyUnitId = propertyUnitId,
        furnitureId = furnitureId,
        model = model,
        label = label,
        position = position,
        rotation = rotation,
        metadata = type(payload.metadata) == 'table' and payload.metadata or {}
    }
end

local function auditFurniture(action, source, metadata)
    metadata = metadata or {
        source = source
    }

    if GetResourceState('nexa_audit') == 'started' then
        exports.nexa_audit:write({
            eventType = 'property',
            severity = 'info',
            action = action,
            resourceName = NexaFurnitureConstants.resourceName,
            metadata = metadata
        })
    end

    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info(NexaFurnitureConstants.resourceName, 'Moebelaktion wurde verarbeitet.', metadata)
    end
end

lib.callback.register(NexaFurnitureConfig.callbacks.load, function(source, payload)
    if not checkRequest(source, NexaFurnitureServerConfig.callbackRateLimits.load) then
        return NexaFurnitureBuildResponse(false, 'RATE_LIMITED', NexaFurnitureLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local propertyUnitId = NexaFurnitureNormalizeId(payload.propertyUnitId, NexaFurnitureServerConfig.maxPropertyUnitId)

    if propertyUnitId == nil then
        return NexaFurnitureBuildResponse(false, 'INVALID_INPUT', NexaFurnitureLocale.invalid, nil, nil)
    end

    return callPropertyApi('property.listFurniture', source, {
        propertyUnitId = propertyUnitId
    })
end)

lib.callback.register(NexaFurnitureConfig.callbacks.place, function(source, payload)
    if not checkRequest(source, NexaFurnitureServerConfig.callbackRateLimits.place) then
        return NexaFurnitureBuildResponse(false, 'RATE_LIMITED', NexaFurnitureLocale.rateLimited, nil, nil)
    end

    local furniturePayload = normalizeTransformPayload(payload, false)

    if furniturePayload == nil then
        return NexaFurnitureBuildResponse(false, 'INVALID_INPUT', NexaFurnitureLocale.invalid, nil, nil)
    end

    if not acquireLock(source, 'place', furniturePayload.propertyUnitId, 0) then
        return NexaFurnitureBuildResponse(false, 'CONFLICT', NexaFurnitureLocale.conflict, nil, nil)
    end

    local ok, result = pcall(function()
        return callPropertyApi('property.placeFurniture', source, furniturePayload)
    end)

    releaseLock(source, 'place', furniturePayload.propertyUnitId, 0)

    if not ok then
        return NexaFurnitureBuildResponse(false, 'INTERNAL_ERROR', NexaFurnitureLocale.internalError, nil, nil)
    end

    if type(result) == 'table' and result.success == true then
        auditFurniture('furniture.place', source, {
            source = source,
            propertyUnitId = furniturePayload.propertyUnitId,
            furnitureId = result.data and result.data.furniture and result.data.furniture.id or nil
        })
    end

    return result
end)

lib.callback.register(NexaFurnitureConfig.callbacks.save, function(source, payload)
    if not checkRequest(source, NexaFurnitureServerConfig.callbackRateLimits.save) then
        return NexaFurnitureBuildResponse(false, 'RATE_LIMITED', NexaFurnitureLocale.rateLimited, nil, nil)
    end

    local furniturePayload = normalizeTransformPayload(payload, true)

    if furniturePayload == nil then
        return NexaFurnitureBuildResponse(false, 'INVALID_INPUT', NexaFurnitureLocale.invalid, nil, nil)
    end

    if not acquireLock(source, 'save', furniturePayload.propertyUnitId, furniturePayload.furnitureId) then
        return NexaFurnitureBuildResponse(false, 'CONFLICT', NexaFurnitureLocale.conflict, nil, nil)
    end

    local ok, result = pcall(function()
        return callPropertyApi('property.saveFurniture', source, furniturePayload)
    end)

    releaseLock(source, 'save', furniturePayload.propertyUnitId, furniturePayload.furnitureId)

    if not ok then
        return NexaFurnitureBuildResponse(false, 'INTERNAL_ERROR', NexaFurnitureLocale.internalError, nil, nil)
    end

    if type(result) == 'table' and result.success == true then
        auditFurniture('furniture.save', source, {
            source = source,
            propertyUnitId = furniturePayload.propertyUnitId,
            furnitureId = furniturePayload.furnitureId
        })
    end

    return result
end)

lib.callback.register(NexaFurnitureConfig.callbacks.remove, function(source, payload)
    if not checkRequest(source, NexaFurnitureServerConfig.callbackRateLimits.remove) then
        return NexaFurnitureBuildResponse(false, 'RATE_LIMITED', NexaFurnitureLocale.rateLimited, nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local propertyUnitId = NexaFurnitureNormalizeId(payload.propertyUnitId, NexaFurnitureServerConfig.maxPropertyUnitId)
    local furnitureId = NexaFurnitureNormalizeId(payload.furnitureId, NexaFurnitureServerConfig.maxFurnitureId)
    local reason = NexaFurnitureTrim(payload.reason)

    if propertyUnitId == nil or furnitureId == nil or reason == '' or #reason > NexaFurnitureServerConfig.maxReasonLength then
        return NexaFurnitureBuildResponse(false, 'INVALID_INPUT', NexaFurnitureLocale.invalid, nil, nil)
    end

    if not acquireLock(source, 'remove', propertyUnitId, furnitureId) then
        return NexaFurnitureBuildResponse(false, 'CONFLICT', NexaFurnitureLocale.conflict, nil, nil)
    end

    local ok, result = pcall(function()
        return callPropertyApi('property.removeFurniture', source, {
            propertyUnitId = propertyUnitId,
            furnitureId = furnitureId,
            reason = reason
        })
    end)

    releaseLock(source, 'remove', propertyUnitId, furnitureId)

    if not ok then
        return NexaFurnitureBuildResponse(false, 'INTERNAL_ERROR', NexaFurnitureLocale.internalError, nil, nil)
    end

    if type(result) == 'table' and result.success == true then
        auditFurniture('furniture.remove', source, {
            source = source,
            propertyUnitId = propertyUnitId,
            furnitureId = furnitureId
        })
    end

    return result
end)
