NexaConfig = {
    debug = GetConvar('nexa:debug', 'false') == 'true',
    environment = GetConvar('nexa:environment', 'development'),
    defaultPermissionRole = 'user',
    identifierPriority = {
        'license',
        'license2',
        'fivem',
        'steam',
        'discord'
    },
    character = {
        maxPerPlayer = tonumber(GetConvar('nexa:maxCharacters', '4')) or 4,
        minNameLength = 2,
        maxNameLength = 32,
        minBirthYear = 1900,
        maxBirthYear = 2010
    },
    callbacks = {
        defaultCooldownMs = 1000
    }
}
