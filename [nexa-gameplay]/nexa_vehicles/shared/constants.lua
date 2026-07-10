NEXA_VEHICLES = {
    resourceName = 'nexa_vehicles',
    version = '0.1.0'
}

NEXA_VEHICLE_OWNER_TYPES = {
    character = 'character',
    organization = 'organization',
    service = 'service',
    system = 'system'
}

NEXA_VEHICLE_STATUS = {
    active = 'active',
    stored = 'stored',
    spawned = 'spawned',
    missing = 'missing',
    impounded = 'impounded',
    disabled = 'disabled',
    deleted = 'deleted'
}

NEXA_VEHICLE_DAMAGE_STATE = {
    none = 'none',
    light = 'light',
    heavy = 'heavy',
    wrecked = 'wrecked'
}

NEXA_VEHICLE_EVENTS = {
    created = 'nexa:internal:vehicles:created',
    transferred = 'nexa:internal:vehicles:transferred',
    spawnRequested = 'nexa:internal:vehicles:spawn_requested',
    spawned = 'nexa:internal:vehicles:spawned',
    despawned = 'nexa:internal:vehicles:despawned',
    stateUpdated = 'nexa:internal:vehicles:state_updated',
    impounded = 'nexa:internal:vehicles:impounded',
    theftAttempted = 'nexa:internal:vehicles:theft_attempted'
}

NEXA_VEHICLE_ERRORS = {
    invalidInput = 'VEHICLE_INVALID_INPUT',
    invalidOwner = 'VEHICLE_INVALID_OWNER',
    invalidDefinition = 'VEHICLE_INVALID_DEFINITION',
    notFound = 'VEHICLE_NOT_FOUND',
    vinExists = 'VEHICLE_VIN_EXISTS',
    plateExists = 'VEHICLE_PLATE_EXISTS',
    databaseError = 'VEHICLE_DATABASE_ERROR',
    forbidden = 'VEHICLE_FORBIDDEN',
    invalidState = 'VEHICLE_INVALID_STATE',
    spawnDenied = 'VEHICLE_SPAWN_DENIED',
    tokenInvalid = 'VEHICLE_SPAWN_TOKEN_INVALID'
}
