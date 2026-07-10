NEXA_CRIME = { resourceName = 'nexa_crime', version = '0.1.0' }

NEXA_CRIME_TYPES = {
    store_robbery = 'store_robbery',
    fuel_robbery = 'fuel_robbery',
    atm_breakin = 'atm_breakin',
    bank_robbery = 'bank_robbery',
    jewellery_robbery = 'jewellery_robbery',
    burglary = 'burglary',
    vehicle_theft = 'vehicle_theft',
    drug_activity = 'drug_activity',
    blackmarket = 'blackmarket',
    fencing = 'fencing',
    laundering = 'laundering',
    custom = 'custom'
}

NEXA_CRIME_SESSION_STATUS = { created = 'created', starting = 'starting', active = 'active', alarmed = 'alarmed', escaped = 'escaped', completed = 'completed', failed = 'failed', cancelled = 'cancelled', expired = 'expired', manual_review = 'manual_review' }
NEXA_CRIME_LOCATION_STATUS = { active = 'active', busy = 'busy', cooldown = 'cooldown', disabled = 'disabled' }
NEXA_CRIME_PHASE_TYPES = { preparation = 'preparation', approach = 'approach', breach = 'breach', intimidation = 'intimidation', access = 'access', loot = 'loot', escape = 'escape', cleanup = 'cleanup' }

NEXA_CRIME_EVENTS = {
    sessionCreated = 'nexa:internal:crime:sessionCreated',
    sessionStarted = 'nexa:internal:crime:sessionStarted',
    sessionAlarmed = 'nexa:internal:crime:sessionAlarmed',
    sessionCompleted = 'nexa:internal:crime:sessionCompleted',
    sessionFailed = 'nexa:internal:crime:sessionFailed',
    reputationChanged = 'nexa:internal:crime:reputationChanged',
    heatChanged = 'nexa:internal:crime:heatChanged'
}

NEXA_CRIME_CALLBACKS = {
    listAvailable = 'nexa:crime:cb:listAvailable',
    getPrerequisites = 'nexa:crime:cb:getPrerequisites',
    getActiveSession = 'nexa:crime:cb:getActiveSession',
    startCrime = 'nexa:crime:cb:startCrime',
    cancelCrime = 'nexa:crime:cb:cancelCrime',
    resolveChallenge = 'nexa:crime:cb:resolveChallenge'
}

NEXA_CRIME_ERRORS = {
    notReady = 'CRIME_NOT_READY',
    definitionNotFound = 'CRIME_DEFINITION_NOT_FOUND',
    definitionNotActive = 'CRIME_DEFINITION_NOT_ACTIVE',
    accessDenied = 'CRIME_ACCESS_DENIED',
    reputationInsufficient = 'CRIME_REPUTATION_INSUFFICIENT',
    heatTooHigh = 'CRIME_HEAT_TOO_HIGH',
    cooldownActive = 'CRIME_COOLDOWN_ACTIVE',
    respondersInsufficient = 'CRIME_RESPONDERS_INSUFFICIENT',
    sessionAlreadyActive = 'CRIME_SESSION_ALREADY_ACTIVE',
    sessionNotFound = 'CRIME_SESSION_NOT_FOUND',
    sessionNotActive = 'CRIME_SESSION_NOT_ACTIVE',
    locationNotFound = 'CRIME_LOCATION_NOT_FOUND',
    locationBusy = 'CRIME_LOCATION_BUSY',
    locationCooldown = 'CRIME_LOCATION_COOLDOWN',
    groupInvalid = 'CRIME_GROUP_INVALID',
    toolRequired = 'CRIME_TOOL_REQUIRED',
    challengeNotFound = 'CRIME_CHALLENGE_NOT_FOUND',
    challengeInvalid = 'CRIME_CHALLENGE_INVALID',
    challengeExpired = 'CRIME_CHALLENGE_EXPIRED',
    challengeReplay = 'CRIME_CHALLENGE_REPLAY',
    phaseInvalid = 'CRIME_PHASE_INVALID',
    reasonRequired = 'CRIME_REASON_REQUIRED',
    rateLimited = 'CRIME_RATE_LIMITED',
    invalidInput = 'CRIME_INVALID_INPUT',
    databaseError = 'CRIME_DATABASE_ERROR'
}
