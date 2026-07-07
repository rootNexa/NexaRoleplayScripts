NexaImpoundServerConfig = {
    defaultFee = 500,
    maxFee = 1000000,
    defaultReleaseGarage = 'stadtgarage',
    maxLocationLength = 64,
    maxReasonLength = 128,
    callbackRateLimits = {
        status = 'nexa:impound:cb:getStatus',
        impound = 'nexa:impound:cb:impoundVehicle',
        release = 'nexa:impound:cb:releaseVehicle'
    },
    locations = {
        {
            id = 'mission_row_impound',
            label = 'Mission Row Verwahrung',
            isActive = true,
            releaseGarageName = 'stadtgarage',
            fee = 500
        },
        {
            id = 'sandy_impound',
            label = 'Sandy Shores Verwahrung',
            isActive = true,
            releaseGarageName = 'sandy_garage',
            fee = 350
        }
    }
}
