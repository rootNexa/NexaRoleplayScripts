NEXA_IDENTITY_CONFIG = {
    cacheTtlMs = 300000,
    statuses = {
        active = true,
        suspended = true,
        banned = true,
        disabled = true,
        pending_review = true
    },
    allowedIdentifierTypes = {
        license = true,
        license2 = true,
        fivem = true,
        discord = true,
        steam = true
    },
    review = {
        markDuplicateStrongSignals = true,
        strongSignalThreshold = 1
    }
}
