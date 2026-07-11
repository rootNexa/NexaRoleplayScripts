NexaItemsConfig = {
    autoMigrate = true,
    maxNameLength = 64,
    maxLabelLength = 128,
    maxDescriptionLength = 2048,
    maxMetadataBytes = 8192,
    maxMetadataDepth = 5,
    maxArrayLength = 64,
    defaultWeight = 0,
    defaultStackable = true,
    defaultMaxStack = 1,
    defaultUsable = false,
    defaultQuickslotAllowed = false,
    defaultDroppable = true,
    defaultTradeable = true,
    defaultDestroyable = true,
    defaultContainerAllowed = false,
    requireReasonForMutations = true,
    permissions = {
        view = 'nexa.items.view',
        create = 'nexa.items.create',
        update = 'nexa.items.update',
        publish = 'nexa.items.publish',
        disable = 'nexa.items.disable',
        delete = 'nexa.items.delete',
        versionsView = 'nexa.items.versions.view',
        rollback = 'nexa.items.rollback',
        assetsManage = 'nexa.items.assets.manage'
    },
    reservedPrefixes = {
        'weapon_',
        'ammo_',
        'document_',
        'key_',
        'container_',
        'medical_',
        'food_',
        'drink_',
        'material_',
        'currency_'
    },
    reservedNames = {
        item = true,
        inventory = true,
        money = true,
        ['nil'] = true,
        null = true
    },
    allowedAssetMimeTypes = {
        ['image/png'] = true,
        ['image/jpeg'] = true,
        ['image/webp'] = true
    },
    maxAssetBytes = 1048576
}
