NexaHousingServerConfig = {
    maxPropertyUnitId = 2147483647,
    maxCharacterId = 2147483647,
    maxListLimit = 50,
    purchaseLockTtlMs = 15000,
    allowedAccessTypes = {
        owner = true,
        tenant = true,
        guest = true,
        temporary = true
    },
    allowedStorageTypes = {
        private = true,
        shared = true
    },
    callbackRateLimits = {
        list = 'nexa:housing:cb:getProperties',
        accessible = 'nexa:housing:cb:getAccessibleProperties',
        status = 'nexa:housing:cb:getStatus',
        access = 'nexa:housing:cb:hasAccess',
        purchase = 'nexa:housing:cb:purchaseProperty',
        rent = 'nexa:housing:cb:rentProperty',
        grantAccess = 'nexa:housing:cb:grantAccess',
        listAccess = 'nexa:housing:cb:listAccess',
        revokeAccess = 'nexa:housing:cb:revokeAccess',
        ensureStorage = 'nexa:housing:cb:ensureStorage',
        openStorage = 'nexa:housing:cb:openStorage'
    }
}
