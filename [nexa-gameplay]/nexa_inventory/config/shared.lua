NexaInventoryConfig = {
    autoMigrate = true,
    defaultMaxWeight = 0,
    defaultMaxSlots = 0,
    defaultAmount = 1,
    maxOwnerTypeLength = 32,
    maxOwnerIdLength = 64,
    maxLabelLength = 128,
    maxItemNameLength = 64,
    requireAdminPermissionForMutations = true,
    adminPermission = 'nexa.inventory.manage'
}

NexaInventoryAllowedOwnerTypes = {
    player = true,
    character = true,
    vehicle = true,
    organization = true,
    storage = true,
    shop = true,
    drop = true,
    container = true,
    custom = true
}
