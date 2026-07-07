NexaVehicleKeysServerConfig = {
    maxReasonLength = 128,
    defaultTemporaryMinutes = 30,
    maxTemporaryMinutes = 1440,
    callbackRateLimits = {
        hasKey = 'nexa:vehiclekeys:cb:hasKey',
        grantKey = 'nexa:vehiclekeys:cb:grantKey',
        grantTemporaryKey = 'nexa:vehiclekeys:cb:grantTemporaryKey',
        revokeKey = 'nexa:vehiclekeys:cb:revokeKey',
        toggleLock = 'nexa:vehiclekeys:cb:toggleLock'
    }
}
