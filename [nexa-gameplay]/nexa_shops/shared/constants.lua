NEXA_SHOPS = {
    resourceName = 'nexa_shops',
    version = '0.1.0'
}

NEXA_SHOPS_TABLES = {
    shops = 'shops',
    shopItems = 'shop_items'
}

NEXA_SHOPS_ERRORS = {
    duplicateName = 'DUPLICATE_SHOP_NAME',
    invalidInput = 'INVALID_INPUT',
    invalidType = 'INVALID_SHOP_TYPE',
    itemNotFound = 'ITEM_NOT_FOUND',
    shopNotFound = 'SHOP_NOT_FOUND',
    shopItemNotFound = 'SHOP_ITEM_NOT_FOUND',
    forbidden = 'FORBIDDEN',
    databaseError = 'DATABASE_ERROR'
}

NEXA_SHOPS_CALLBACKS = {
    createShop = 'nexa:shops:cb:createShop',
    getShop = 'nexa:shops:cb:getShop',
    listShops = 'nexa:shops:cb:listShops',
    updateShop = 'nexa:shops:cb:updateShop',
    setShopEnabled = 'nexa:shops:cb:setShopEnabled',
    deleteShop = 'nexa:shops:cb:deleteShop',
    addShopItem = 'nexa:shops:cb:addShopItem',
    listShopItems = 'nexa:shops:cb:listShopItems',
    updateShopItem = 'nexa:shops:cb:updateShopItem',
    removeShopItem = 'nexa:shops:cb:removeShopItem'
}
