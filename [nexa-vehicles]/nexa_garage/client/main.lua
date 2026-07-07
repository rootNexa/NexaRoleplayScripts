local cachedVehicles = {}

local function notify(message, notifyType)
    if lib and lib.notify then
        lib.notify({
            title = NexaGarageLocale.title,
            description = message,
            type = notifyType or 'inform'
        })
    end
end

local function listVehicles(garageName)
    local response = lib.callback.await(NexaGarageConfig.callbacks.list, false, {
        garageName = garageName or NexaGarageClientConfig.defaultGarageName
    })

    if type(response) ~= 'table' or response.success ~= true then
        notify(NexaGarageLocale.denied, 'error')
        return {}
    end

    cachedVehicles = response.data and response.data.vehicles or {}
    notify(NexaGarageLocale.listLoaded, 'success')
    return cachedVehicles
end

local function storeVehicle(vehicleId, garageName)
    local response = lib.callback.await(NexaGarageConfig.callbacks.store, false, {
        vehicleId = vehicleId,
        garageName = garageName or NexaGarageClientConfig.defaultGarageName
    })

    notify(type(response) == 'table' and response.message or NexaGarageLocale.denied, type(response) == 'table' and response.success == true and 'success' or 'error')

    return response
end

local function retrieveVehicle(vehicleId, garageName)
    local response = lib.callback.await(NexaGarageConfig.callbacks.retrieve, false, {
        vehicleId = vehicleId,
        garageName = garageName or NexaGarageClientConfig.defaultGarageName
    })

    notify(type(response) == 'table' and response.message or NexaGarageLocale.denied, type(response) == 'table' and response.success == true and 'success' or 'error')

    return response
end

CreateThread(function()
    if NexaGarageClientConfig.enableCommand then
        RegisterCommand(NexaGarageClientConfig.commandName, function()
            listVehicles(NexaGarageClientConfig.defaultGarageName)
        end, false)
    end
end)

RegisterNetEvent(NEXA_GARAGE_EVENTS.open, function(garageName)
    listVehicles(garageName)
end)

RegisterNetEvent(NEXA_GARAGE_EVENTS.refresh, function(garageName)
    listVehicles(garageName)
end)

exports('listVehicles', listVehicles)
exports('storeVehicle', storeVehicle)
exports('retrieveVehicle', retrieveVehicle)
exports('getCachedVehicles', function()
    return cachedVehicles
end)
