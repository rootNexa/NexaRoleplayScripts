NEXA_INVENTORY = {
    resourceName = 'nexa_inventory',
    version = '0.2.0'
}

NEXA_INVENTORY_TABLES = {
    inventories = 'nexa_inventories',
    items = 'nexa_inventory_items',
    quickslots = 'nexa_inventory_quickslots',
    audit = 'nexa_inventory_audit'
}

NEXA_INVENTORY_STATUS = {
    unloaded = 'unloaded',
    loading = 'loading',
    ready = 'ready',
    locked = 'locked',
    saving = 'saving',
    unloading = 'unloading',
    failed = 'failed'
}

NEXA_INVENTORY_ERRORS = {
    notFound = 'INVENTORY_NOT_FOUND',
    notReady = 'INVENTORY_NOT_READY',
    locked = 'INVENTORY_LOCKED',
    busy = 'INVENTORY_BUSY',
    accessDenied = 'INVENTORY_ACCESS_DENIED',
    slotInvalid = 'INVENTORY_SLOT_INVALID',
    slotOccupied = 'INVENTORY_SLOT_OCCUPIED',
    slotEmpty = 'INVENTORY_SLOT_EMPTY',
    noFreeSlot = 'INVENTORY_NO_FREE_SLOT',
    weightExceeded = 'INVENTORY_WEIGHT_EXCEEDED',
    versionConflict = 'INVENTORY_VERSION_CONFLICT',
    itemNotFound = 'ITEM_NOT_FOUND',
    itemDefinitionNotFound = 'ITEM_DEFINITION_NOT_FOUND',
    itemAmountInvalid = 'ITEM_AMOUNT_INVALID',
    itemAmountInsufficient = 'ITEM_AMOUNT_INSUFFICIENT',
    itemNotStackable = 'ITEM_NOT_STACKABLE',
    itemStackLimitExceeded = 'ITEM_STACK_LIMIT_EXCEEDED',
    itemMetadataInvalid = 'ITEM_METADATA_INVALID',
    itemInstanceConflict = 'ITEM_INSTANCE_CONFLICT',
    transferTargetInvalid = 'TRANSFER_TARGET_INVALID',
    transferDistanceExceeded = 'TRANSFER_DISTANCE_EXCEEDED',
    transferBucketMismatch = 'TRANSFER_BUCKET_MISMATCH',
    quickslotInvalid = 'QUICKSLOT_INVALID',
    quickslotItemInvalid = 'QUICKSLOT_ITEM_INVALID',
    containerNestingForbidden = 'CONTAINER_NESTING_FORBIDDEN',
    containerNotFound = 'CONTAINER_NOT_FOUND',
    containerBusy = 'CONTAINER_BUSY',
    dropNotFound = 'DROP_NOT_FOUND',
    dropExpired = 'DROP_EXPIRED',
    dropDistanceExceeded = 'DROP_DISTANCE_EXCEEDED',
    dropBucketMismatch = 'DROP_BUCKET_MISMATCH',
    integrityFailed = 'INVENTORY_INTEGRITY_FAILED',
    rateLimited = 'INVENTORY_OPERATION_RATE_LIMITED',
    invalidInput = 'INVENTORY_INVALID_INPUT',
    databaseError = 'INVENTORY_DATABASE_ERROR'
}

NEXA_INVENTORY_EVENTS = {
    ready = 'nexa:internal:inventory:ready',
    unloading = 'nexa:internal:inventory:unloading',
    itemAdded = 'nexa:internal:inventory:itemAdded',
    itemRemoved = 'nexa:internal:inventory:itemRemoved',
    itemTransferred = 'nexa:internal:inventory:itemTransferred',
    weightChanged = 'nexa:internal:inventory:weightChanged',
    dropCreated = 'nexa:internal:inventory:dropCreated',
    dropRemoved = 'nexa:internal:inventory:dropRemoved',
    integrityFailed = 'nexa:internal:inventory:integrityFailed'
}

NEXA_INVENTORY_CALLBACKS = {
    getInventory = 'nexa:inventory:cb:getInventory',
    listItems = 'nexa:inventory:cb:listItems',
    moveItem = 'nexa:inventory:cb:moveItem',
    splitStack = 'nexa:inventory:cb:splitStack',
    giveItem = 'nexa:inventory:cb:giveItem',
    dropItem = 'nexa:inventory:cb:dropItem',
    pickupDrop = 'nexa:inventory:cb:pickupDrop',
    assignQuickslot = 'nexa:inventory:cb:assignQuickslot',
    clearQuickslot = 'nexa:inventory:cb:clearQuickslot',
    openContainer = 'nexa:inventory:cb:openContainer'
}
