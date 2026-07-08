NEXA_CHARACTER_CONSTANTS = {
    resourceName = 'nexa-character',
    events = {
        server = {
            list = 'nexa-character:server:list',
            create = 'nexa-character:server:create',
            select = 'nexa-character:server:select',
            update = 'nexa-character:server:update'
        },
        client = {
            charactersLoaded = 'nexa-character:client:charactersLoaded',
            characterSelected = 'nexa-character:client:characterSelected',
            characterUpdated = 'nexa-character:client:characterUpdated'
        }
    },
    errors = {
        invalidInput = 'INVALID_INPUT',
        coreUnavailable = 'CORE_UNAVAILABLE',
        notFound = 'NOT_FOUND',
        denied = 'SECURITY_REJECTED'
    }
}
