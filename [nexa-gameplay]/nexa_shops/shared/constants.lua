NEXA_SHOPS = { resourceName = 'nexa_shops', version = '0.2.0' }

NEXA_SHOP_TYPES = {
    government = 'government',
    general = 'general',
    organization = 'organization',
    business = 'business',
    illegal = 'illegal',
    service = 'service',
    vehicle_related = 'vehicle_related',
    medical = 'medical',
    weapon = 'weapon',
    temporary = 'temporary',
    custom = 'custom'
}

NEXA_SHOP_STATUS = { draft = 'draft', active = 'active', suspended = 'suspended', disabled = 'disabled', archived = 'archived', deleted = 'deleted' }
NEXA_SHOP_STOCK_MODE = { infinite = 'infinite', finite_virtual = 'finite_virtual', inventory_backed = 'inventory_backed', production_backed = 'production_backed' }
NEXA_SHOP_TRANSACTION_STATUS = { pending = 'pending', completed = 'completed', failed = 'failed', manual_review = 'manual_review', duplicate = 'duplicate' }
NEXA_SHOP_DELIVERY_STATUS = { created = 'created', assigned = 'assigned', picked_up = 'picked_up', in_transit = 'in_transit', delivered = 'delivered', cancelled = 'cancelled', failed = 'failed' }

NEXA_SHOP_EVENTS = {
    created = 'nexa:internal:shop:created',
    activated = 'nexa:internal:shop:activated',
    purchaseCompleted = 'nexa:internal:shop:purchaseCompleted',
    purchaseFailed = 'nexa:internal:shop:purchaseFailed',
    saleCompleted = 'nexa:internal:shop:saleCompleted',
    stockChanged = 'nexa:internal:shop:stockChanged',
    restocked = 'nexa:internal:shop:restocked',
    deliveryCompleted = 'nexa:internal:shop:deliveryCompleted'
}

NEXA_SHOP_ERRORS = {
    notFound = 'SHOP_NOT_FOUND',
    typeInvalid = 'SHOP_TYPE_INVALID',
    notActive = 'SHOP_NOT_ACTIVE',
    accessDenied = 'SHOP_ACCESS_DENIED',
    itemNotFound = 'SHOP_ITEM_NOT_FOUND',
    itemDisabled = 'SHOP_ITEM_DISABLED',
    priceInvalid = 'SHOP_PRICE_INVALID',
    stockInsufficient = 'SHOP_STOCK_INSUFFICIENT',
    stockFull = 'SHOP_STOCK_FULL',
    purchaseLimit = 'SHOP_PURCHASE_LIMIT',
    licenseRequired = 'SHOP_LICENSE_REQUIRED',
    buyForbidden = 'SHOP_BUY_FORBIDDEN',
    sellForbidden = 'SHOP_SELL_FORBIDDEN',
    transactionFailed = 'SHOP_TRANSACTION_FAILED',
    transactionDuplicate = 'SHOP_TRANSACTION_DUPLICATE',
    deliveryNotFound = 'SHOP_DELIVERY_NOT_FOUND',
    deliveryInvalid = 'SHOP_DELIVERY_INVALID',
    reasonRequired = 'SHOP_REASON_REQUIRED',
    rateLimited = 'SHOP_RATE_LIMITED',
    invalidInput = 'SHOP_INVALID_INPUT',
    databaseError = 'SHOP_DATABASE_ERROR'
}
