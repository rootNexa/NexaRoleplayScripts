local function notify(response)
    if lib and lib.notify then
        lib.notify({
            title = NexaImpoundLocale.title,
            description = type(response) == 'table' and response.message or NexaImpoundLocale.denied,
            type = type(response) == 'table' and response.success == true and 'success' or 'error'
        })
    end
end

local function getStatus(vehicleId)
    return lib.callback.await(NexaImpoundConfig.callbacks.status, false, {
        vehicleId = vehicleId
    })
end

local function impoundVehicle(vehicleId, locationId, reason)
    local response = lib.callback.await(NexaImpoundConfig.callbacks.impound, false, {
        vehicleId = vehicleId,
        locationId = locationId,
        reason = reason
    })

    notify(response)
    return response
end

local function releaseVehicle(vehicleId, fee, accountReference, garageName)
    accountReference = type(accountReference) == 'table' and accountReference or {}

    local response = lib.callback.await(NexaImpoundConfig.callbacks.release, false, {
        vehicleId = vehicleId,
        fee = fee,
        accountId = accountReference.accountId,
        accountNumber = accountReference.accountNumber,
        garageName = garageName
    })

    notify(response)
    return response
end

CreateThread(function()
    if NexaImpoundClientConfig.enableCommand then
        RegisterCommand(NexaImpoundClientConfig.statusCommand, function(_, args)
            getStatus(tonumber(args[1]))
        end, false)
    end
end)

exports('getStatus', getStatus)
exports('impoundVehicle', impoundVehicle)
exports('releaseVehicle', releaseVehicle)
