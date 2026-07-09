NEXA_INVENTORY = {
    resourceName = 'nexa_inventory',
    version = '0.1.0'
}

NEXA_INVENTORY_TABLES = {
    inventories = 'inventories',
    inventoryItems = 'inventory_items'
}

NEXA_INVENTORY_ERRORS = {
    duplicateInventory = 'DUPLICATE_INVENTORY',
    invalidInput = 'INVALID_INPUT',
    invalidOwnerType = 'INVALID_OWNER_TYPE',
    invalidItem = 'INVALID_ITEM',
    notFound = 'NOT_FOUND',
    forbidden = 'FORBIDDEN',
    databaseError = 'DATABASE_ERROR'
}

NEXA_INVENTORY_CALLBACKS = {
    getInventory = 'nexa:inventory:cb:getInventory',
    listItems = 'nexa:inventory:cb:listItems',
    addItem = 'nexa:inventory:cb:addItem',
    removeItem = 'nexa:inventory:cb:removeItem',
    moveItem = 'nexa:inventory:cb:moveItem'
}
