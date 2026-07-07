local function notify(response)
    if lib and lib.notify then
        lib.notify({
            title = NexaVehicleKeysLocale.title,
            description = type(response) == 'table' and response.message or NexaVehicleKeysLocale.denied,
            type = type(response) == 'table' and response.success == true and 'success' or 'error'
        })
    end
end

local function hasKey(vehicleId)
    return lib.callback.await(NexaVehicleKeysConfig.callbacks.hasKey, false, {
        vehicleId = vehicleId
    })
end

local function grantKey(vehicleId, characterId, reason)
    local response = lib.callback.await(NexaVehicleKeysConfig.callbacks.grantKey, false, {
        vehicleId = vehicleId,
        characterId = characterId,
        reason = reason
    })

    notify(response)
    return response
end

local function grantTemporaryKey(vehicleId, characterId, durationMinutes, reason)
    local response = lib.callback.await(NexaVehicleKeysConfig.callbacks.grantTemporaryKey, false, {
        vehicleId = vehicleId,
        characterId = characterId,
        durationMinutes = durationMinutes,
        reason = reason
    })

    notify(response)
    return response
end

local function revokeKey(vehicleId, characterId, keyType, reason)
    local response = lib.callback.await(NexaVehicleKeysConfig.callbacks.revokeKey, false, {
        vehicleId = vehicleId,
        characterId = characterId,
        keyType = keyType,
        reason = reason
    })

    notify(response)
    return response
end

local function toggleLock(vehicleId)
    local response = lib.callback.await(NexaVehicleKeysConfig.callbacks.toggleLock, false, {
        vehicleId = vehicleId
    })

    notify(response)
    return response
end

CreateThread(function()
    if NexaVehicleKeysClientConfig.enableCommand then
        RegisterCommand(NexaVehicleKeysClientConfig.commandName, function(_, args)
            toggleLock(tonumber(args[1]))
        end, false)
    end
end)

exports('hasKey', hasKey)
exports('grantKey', grantKey)
exports('grantTemporaryKey', grantTemporaryKey)
exports('revokeKey', revokeKey)
exports('toggleLock', toggleLock)
