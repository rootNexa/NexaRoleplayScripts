NexaGarageServerConfig = {
    defaultGarageName = 'stadtgarage',
    maxGarageNameLength = 64,
    lockTtlMs = 15000,
    callbackRateLimits = {
        list = 'nexa:garage:cb:listVehicles',
        store = 'nexa:garage:cb:storeVehicle',
        retrieve = 'nexa:garage:cb:retrieveVehicle'
    }
}
