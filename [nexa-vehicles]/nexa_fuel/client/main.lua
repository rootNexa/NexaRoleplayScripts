local function notify(response)
    if lib and lib.notify then
        lib.notify({
            title = NexaFuelLocale.title,
            description = type(response) == 'table' and response.message or NexaFuelLocale.denied,
            type = type(response) == 'table' and response.success == true and 'success' or 'error'
        })
    end
end

local function getStations()
    return lib.callback.await(NexaFuelConfig.callbacks.stations, false, {})
end

local function getFuel(vehicleId)
    return lib.callback.await(NexaFuelConfig.callbacks.fuel, false, {
        vehicleId = vehicleId
    })
end

local function purchaseFuel(stationId, vehicleId, liters, accountReference)
    accountReference = type(accountReference) == 'table' and accountReference or {}

    local response = lib.callback.await(NexaFuelConfig.callbacks.purchase, false, {
        stationId = stationId,
        vehicleId = vehicleId,
        liters = liters,
        accountId = accountReference.accountId,
        accountNumber = accountReference.accountNumber
    })

    notify(response)
    return response
end

local function reportConsumption(vehicleId, consumed)
    return lib.callback.await(NexaFuelConfig.callbacks.consumption, false, {
        vehicleId = vehicleId,
        consumed = consumed
    })
end

CreateThread(function()
    if NexaFuelClientConfig.enableCommand then
        RegisterCommand(NexaFuelClientConfig.stationCommand, function()
            getStations()
        end, false)
    end
end)

exports('getStations', getStations)
exports('getFuel', getFuel)
exports('purchaseFuel', purchaseFuel)
exports('reportConsumption', reportConsumption)
