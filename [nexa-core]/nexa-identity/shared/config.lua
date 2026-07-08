NexaIdentityConfig = {
    devMode = GetConvar('nexa:environment', 'development') == 'development',
    requestDelayMs = 2000,
    maxNameLength = 32,
    allowedGenders = {
        male = true,
        female = true,
        diverse = true,
        unknown = true
    }
}

NexaIdentityEvents = {
    server = {
        requestFlow = 'nexa-identity:server:requestFlow',
        createCharacter = 'nexa-identity:server:createCharacter',
        selectCharacter = 'nexa-identity:server:selectCharacter'
    },
    client = {
        open = 'nexa-identity:client:open',
        close = 'nexa-identity:client:close',
        error = 'nexa-identity:client:error',
        selected = 'nexa-identity:client:selected'
    }
}
