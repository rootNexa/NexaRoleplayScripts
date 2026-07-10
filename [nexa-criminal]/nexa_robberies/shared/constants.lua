NEXA_ROBBERIES = { resourceName = 'nexa_robberies', version = '0.1.0' }

NEXA_ROBBERY_TYPES = {
    store = 'store',
    fuel = 'fuel',
    atm = 'atm',
    bank = 'bank',
    jeweller = 'jeweller',
    burglary = 'burglary',
    vehicle_theft = 'vehicle_theft'
}

NEXA_ROBBERY_EVENTS = {
    started = 'nexa:internal:robbery:started',
    phaseChanged = 'nexa:internal:robbery:phaseChanged',
    alarmTriggered = 'nexa:internal:robbery:alarmTriggered',
    lootClaimed = 'nexa:internal:robbery:lootClaimed',
    completed = 'nexa:internal:robbery:completed',
    locationReset = 'nexa:internal:robbery:locationReset'
}

NEXA_ROBBERY_ERRORS = {
    notFound = 'ROBBERY_NOT_FOUND',
    notActive = 'ROBBERY_NOT_ACTIVE',
    alarmAlreadyTriggered = 'ROBBERY_ALARM_ALREADY_TRIGGERED',
    lootPointNotFound = 'ROBBERY_LOOT_POINT_NOT_FOUND',
    lootAlreadyClaimed = 'ROBBERY_LOOT_ALREADY_CLAIMED',
    lootFailed = 'ROBBERY_LOOT_FAILED',
    locationResetRequired = 'ROBBERY_LOCATION_RESET_REQUIRED',
    vaultNotOpen = 'ROBBERY_VAULT_NOT_OPEN',
    escapeNotReached = 'ROBBERY_ESCAPE_NOT_REACHED',
    invalidInput = 'ROBBERY_INVALID_INPUT',
    databaseError = 'ROBBERY_DATABASE_ERROR'
}
