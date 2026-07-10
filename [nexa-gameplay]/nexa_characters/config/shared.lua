NEXA_CHARACTERS_CONFIG = {
    maxCharacters = 3,
    futureMaxCharacters = 5,
    minNameLength = 2,
    maxNameLength = 32,
    minBirthYear = 1900,
    maxBirthYear = 2008,
    minHeight = 120,
    maxHeight = 230,
    minWeight = 35,
    maxWeight = 220,
    defaultStatus = 'active',
    allowedGenders = {
        male = true,
        female = true,
        diverse = true,
        unknown = true
    },
    protectedUpdateFields = {
        id = true,
        account_id = true,
        accountId = true,
        player_id = true,
        playerId = true,
        created_at = true,
        createdAt = true,
        deleted_at = true,
        deletedAt = true
    }
}
