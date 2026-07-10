NEXA_CONSTANTS = {
    resourceName = 'nexa-core',
    version = '0.1.0',
    events = {
        playerLoaded = 'nexa:core:client:playerLoaded',
        characterSelected = 'nexa:core:client:characterSelected',
        characterUnloaded = 'nexa:core:client:characterUnloaded'
    },
    serverEvents = {
        selectCharacter = 'nexa:core:server:selectCharacter'
    },
    callbacks = {
        getSession = 'nexa:core:cb:getSession',
        getCharacters = 'nexa:core:cb:getCharacters',
        clientRequest = 'nexa:core:callbacks:clientRequest',
        clientResponse = 'nexa:core:callbacks:clientResponse',
        serverRequest = 'nexa:core:callbacks:serverRequest',
        serverResponse = 'nexa:core:callbacks:serverResponse'
    },
    lifecycle = {
        states = {
            created = 'created',
            initializing = 'initializing',
            initialized = 'initialized',
            starting = 'starting',
            ready = 'ready',
            stopping = 'stopping',
            stopped = 'stopped',
            failed = 'failed'
        },
        stages = {
            initializing = 'initializing',
            initialized = 'initialized',
            starting = 'starting',
            ready = 'ready',
            stopping = 'stopping',
            stopped = 'stopped',
            failed = 'failed'
        },
        requiredResources = {
            'oxmysql'
        }
    },
    errors = {
        ok = 'OK',
        invalidInput = 'INVALID_INPUT',
        notFound = 'NOT_FOUND',
        noPermission = 'NO_PERMISSION',
        database = 'DATABASE_ERROR',
        security = 'SECURITY_REJECTED',
        characterNotLoaded = 'CHARACTER_NOT_LOADED',
        coreNotReady = 'CORE_NOT_READY',
        lifecycle = 'LIFECYCLE_ERROR',
        internal = 'INTERNAL_ERROR'
    }
}
