NexaInventoryConfig = {
    autoMigrate = true,
    defaultCharacterSlots = 30,
    defaultCharacterWeight = 30000,
    defaultQuickslots = 5,
    defaultDropTtlSeconds = 300,
    defaultTemporaryTtlSeconds = 300,
    defaultContainerSlots = 20,
    defaultContainerWeight = 20000,
    lockTimeoutMs = 5000,
    maxMetadataBytes = 4096,
    maxMetadataDepth = 4,
    maxItemNameLength = 64,
    maxOwnerIdLength = 64,
    maxInventoryTypeLength = 32,
    maxOwnerTypeLength = 32,
    maxSnapshotDistance = 4.0,
    transferDistance = 3.0
}

NexaInventoryTypes = {
    character = true,
    container = true,
    drop = true,
    temporary = true,
    vehicle_trunk = true,
    vehicle_glovebox = true,
    property_storage = true,
    organization_storage = true,
    evidence = true,
    shop = true,
    crafting_input = true,
    crafting_output = true
}

NexaInventoryOwnerTypes = {
    character = true,
    account = true,
    system = true,
    world = true,
    container_item = true
}
