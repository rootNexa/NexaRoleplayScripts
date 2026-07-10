NEXA_ECONOMY = {
    resourceName = 'nexa_economy',
    version = '0.1.0'
}

NEXA_ECONOMY_CURRENCIES = {
    bank = 'bank',
    cash = 'cash',
    dirtyCash = 'dirty_cash'
}

NEXA_ECONOMY_CURRENCY_TYPES = {
    account = 'account',
    item = 'item'
}

NEXA_ECONOMY_ACCOUNT_TYPES = {
    characterBank = 'character_bank',
    organization = 'organization',
    government = 'government',
    system = 'system',
    escrow = 'escrow',
    temporary = 'temporary'
}

NEXA_ECONOMY_ACCOUNT_STATUS = {
    active = 'active',
    disabled = 'disabled',
    closed = 'closed'
}

NEXA_ECONOMY_TRANSACTION_TYPES = {
    credit = 'credit',
    debit = 'debit',
    transfer = 'transfer',
    adjust = 'adjust',
    reverse = 'reverse',
    reservation = 'reservation',
    reservationCapture = 'reservation_capture',
    reservationRelease = 'reservation_release',
    depositCash = 'deposit_cash',
    withdrawCash = 'withdraw_cash'
}

NEXA_ECONOMY_TRANSACTION_STATUS = {
    pending = 'pending',
    completed = 'completed',
    failed = 'failed',
    reversed = 'reversed'
}

NEXA_ECONOMY_RESERVATION_STATUS = {
    active = 'active',
    captured = 'captured',
    released = 'released',
    expired = 'expired'
}

NEXA_ECONOMY_SAGA_STATUS = {
    started = 'started',
    completed = 'completed',
    compensating = 'compensating',
    compensated = 'compensated',
    failed = 'failed'
}

NEXA_ECONOMY_ERRORS = {
    invalidInput = 'ECONOMY_INVALID_INPUT',
    invalidAmount = 'ECONOMY_INVALID_AMOUNT',
    invalidCurrency = 'ECONOMY_INVALID_CURRENCY',
    invalidAccountType = 'ECONOMY_INVALID_ACCOUNT_TYPE',
    accountNotFound = 'ECONOMY_ACCOUNT_NOT_FOUND',
    accountDisabled = 'ECONOMY_ACCOUNT_DISABLED',
    insufficientFunds = 'ECONOMY_INSUFFICIENT_FUNDS',
    reservationNotFound = 'ECONOMY_RESERVATION_NOT_FOUND',
    reservationInvalidState = 'ECONOMY_RESERVATION_INVALID_STATE',
    idempotencyConflict = 'ECONOMY_IDEMPOTENCY_CONFLICT',
    databaseError = 'ECONOMY_DATABASE_ERROR',
    dependencyMissing = 'ECONOMY_DEPENDENCY_MISSING',
    inventoryError = 'ECONOMY_INVENTORY_ERROR',
    permissionDenied = 'ECONOMY_PERMISSION_DENIED',
    reasonRequired = 'ECONOMY_REASON_REQUIRED'
}

NEXA_ECONOMY_CALLBACKS = {
    getOwnBalance = 'nexa:economy:cb:getOwnBalance',
    getLedger = 'nexa:economy:cb:getLedger',
    transfer = 'nexa:economy:cb:transfer',
    depositCash = 'nexa:economy:cb:depositCash',
    withdrawCash = 'nexa:economy:cb:withdrawCash'
}
