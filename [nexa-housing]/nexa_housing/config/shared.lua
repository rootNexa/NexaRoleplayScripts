NexaHousingConfig = {
    locale = 'de',
    callbacks = {
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
