local function notifyResult(result, fallback)
    if not NexaFurnitureClientConfig.notify then
        return
    end

    if type(lib) ~= 'table' or type(lib.notify) ~= 'function' then
        return
    end

    local success = type(result) == 'table' and result.success == true

    lib.notify({
        title = 'Einrichtung',
        description = type(result) == 'table' and result.message or fallback,
        type = success and 'success' or 'error'
    })
end

local function requestFurniture(callbackName, payload, fallback)
    local result = lib.callback.await(callbackName, false, payload or {})
    notifyResult(result, fallback)

    return result
end

local function loadFurniture(payload)
    return requestFurniture(NexaFurnitureConfig.callbacks.load, payload, NexaFurnitureLocale.loaded)
end

local function placeFurniture(payload)
    return requestFurniture(NexaFurnitureConfig.callbacks.place, payload, NexaFurnitureLocale.placed)
end

local function saveFurniture(payload)
    return requestFurniture(NexaFurnitureConfig.callbacks.save, payload, NexaFurnitureLocale.saved)
end

local function removeFurniture(payload)
    return requestFurniture(NexaFurnitureConfig.callbacks.remove, payload, NexaFurnitureLocale.removed)
end

exports('loadFurniture', loadFurniture)
exports('placeFurniture', placeFurniture)
exports('saveFurniture', saveFurniture)
exports('removeFurniture', removeFurniture)
