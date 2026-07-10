NEXA_BLACKMARKET = { resourceName = 'nexa_blackmarket', version = '0.1.0' }

NEXA_BLACKMARKET_TYPES = {
    tools = 'tools',
    documents = 'documents',
    weapons = 'weapons',
    vehicle_parts = 'vehicle_parts',
    stolen_goods = 'stolen_goods',
    custom = 'custom'
}

NEXA_BLACKMARKET_EVENTS = {
    purchaseCompleted = 'nexa:internal:blackmarket:purchaseCompleted',
    fenceSaleCompleted = 'nexa:internal:blackmarket:fenceSaleCompleted',
    launderingStarted = 'nexa:internal:moneylaundering:started',
    launderingCompleted = 'nexa:internal:moneylaundering:completed',
    launderingReviewRequired = 'nexa:internal:moneylaundering:reviewRequired'
}

NEXA_BLACKMARKET_ERRORS = {
    notFound = 'BLACKMARKET_NOT_FOUND',
    accessDenied = 'BLACKMARKET_ACCESS_DENIED',
    itemNotFound = 'BLACKMARKET_ITEM_NOT_FOUND',
    priceInvalid = 'BLACKMARKET_PRICE_INVALID',
    fenceItemNotAccepted = 'FENCE_ITEM_NOT_ACCEPTED',
    fenceOfferInvalid = 'FENCE_OFFER_INVALID',
    launderingNotFound = 'MONEYLAUNDERING_NOT_FOUND',
    launderingAmountInvalid = 'MONEYLAUNDERING_AMOUNT_INVALID',
    launderingAccessDenied = 'MONEYLAUNDERING_ACCESS_DENIED',
    launderingAlreadyCompleted = 'MONEYLAUNDERING_ALREADY_COMPLETED',
    launderingCompensationFailed = 'MONEYLAUNDERING_COMPENSATION_FAILED',
    launderingReviewRequired = 'MONEYLAUNDERING_REVIEW_REQUIRED',
    invalidInput = 'BLACKMARKET_INVALID_INPUT',
    databaseError = 'BLACKMARKET_DATABASE_ERROR'
}
