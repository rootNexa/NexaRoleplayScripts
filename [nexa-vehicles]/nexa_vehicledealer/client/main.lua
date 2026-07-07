local function notify(response)
    if lib and lib.notify then
        lib.notify({
            title = NexaVehicleDealerLocale.title,
            description = type(response) == 'table' and response.message or NexaVehicleDealerLocale.denied,
            type = type(response) == 'table' and response.success == true and 'success' or 'error'
        })
    end
end

local function getCatalog(dealerId)
    return lib.callback.await(NexaVehicleDealerConfig.callbacks.catalog, false, {
        dealerId = dealerId
    })
end

local function purchaseVehicle(dealerId, catalogId, accountReference)
    accountReference = type(accountReference) == 'table' and accountReference or {}

    local response = lib.callback.await(NexaVehicleDealerConfig.callbacks.purchase, false, {
        dealerId = dealerId,
        catalogId = catalogId,
        accountId = accountReference.accountId,
        accountNumber = accountReference.accountNumber
    })

    notify(response)
    return response
end

local function prepareSale(vehicleId)
    local response = lib.callback.await(NexaVehicleDealerConfig.callbacks.prepareSale, false, {
        vehicleId = vehicleId
    })

    notify(response)
    return response
end

CreateThread(function()
    if NexaVehicleDealerClientConfig.enableCommand then
        RegisterCommand(NexaVehicleDealerClientConfig.catalogCommand, function()
            getCatalog('premium_deluxe')
        end, false)
    end
end)

exports('getCatalog', getCatalog)
exports('purchaseVehicle', purchaseVehicle)
exports('prepareSale', prepareSale)
