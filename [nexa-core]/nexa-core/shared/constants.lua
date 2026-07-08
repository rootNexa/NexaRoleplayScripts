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
    errors = {
        ok = 'OK',
        invalidInput = 'INVALID_INPUT',
        notFound = 'NOT_FOUND',
        noPermission = 'NO_PERMISSION',
        database = 'DATABASE_ERROR',
        security = 'SECURITY_REJECTED',
        characterNotLoaded = 'CHARACTER_NOT_LOADED',
        internal = 'INTERNAL_ERROR'
    }
}
