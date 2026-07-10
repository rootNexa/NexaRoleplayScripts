NEXA_PROPERTIES = { resourceName = 'nexa_properties', version = '0.1.0' }

NEXA_PROPERTY_TYPES = {
    rental_apartment = 'rental_apartment',
    owned_apartment = 'owned_apartment',
    house = 'house',
    villa = 'villa',
    business_building = 'business_building',
    garage = 'garage',
    motel = 'motel',
    hotel = 'hotel',
    warehouse = 'warehouse',
    office = 'office',
    shop = 'shop',
    land = 'land'
}

NEXA_PROPERTY_STATUS = { draft = 'draft', active = 'active', disabled = 'disabled', archived = 'archived', deleted = 'deleted' }
NEXA_PROPERTY_OWNERSHIP_STATUS = { unowned = 'unowned', owned = 'owned', for_sale = 'for_sale', reserved = 'reserved', seized = 'seized', archived = 'archived' }
NEXA_PROPERTY_OWNER_TYPES = { character = 'character', organization = 'organization', government = 'government', system = 'system' }
NEXA_PROPERTY_LEASE_STATUS = { draft = 'draft', active = 'active', overdue = 'overdue', suspended = 'suspended', terminated = 'terminated', expired = 'expired', evicted = 'evicted' }
NEXA_PROPERTY_RESIDENT_STATUS = { invited = 'invited', active = 'active', suspended = 'suspended', removed = 'removed', expired = 'expired' }
NEXA_PROPERTY_RESIDENT_TYPES = { owner = 'owner', tenant = 'tenant', roommate = 'roommate', guest = 'guest', organization_member = 'organization_member', service_access = 'service_access' }

NEXA_PROPERTY_EVENTS = {
    created = 'nexa:internal:property:created',
    activated = 'nexa:internal:property:activated',
    purchased = 'nexa:internal:property:purchased',
    sold = 'nexa:internal:property:sold',
    ownershipChanged = 'nexa:internal:property:ownershipChanged',
    leaseCreated = 'nexa:internal:property:leaseCreated',
    leaseEnded = 'nexa:internal:property:leaseEnded',
    rentPaid = 'nexa:internal:property:rentPaid',
    rentOverdue = 'nexa:internal:property:rentOverdue',
    residentJoined = 'nexa:internal:property:residentJoined',
    residentRemoved = 'nexa:internal:property:residentRemoved'
}

NEXA_PROPERTY_ERRORS = {
    notFound = 'PROPERTY_NOT_FOUND',
    definitionNotFound = 'PROPERTY_DEFINITION_NOT_FOUND',
    typeInvalid = 'PROPERTY_TYPE_INVALID',
    statusInvalid = 'PROPERTY_STATUS_INVALID',
    notActive = 'PROPERTY_NOT_ACTIVE',
    notForSale = 'PROPERTY_NOT_FOR_SALE',
    notRentable = 'PROPERTY_NOT_RENTABLE',
    alreadyOwned = 'PROPERTY_ALREADY_OWNED',
    ownerInvalid = 'PROPERTY_OWNER_INVALID',
    accessDenied = 'PROPERTY_ACCESS_DENIED',
    priceInvalid = 'PROPERTY_PRICE_INVALID',
    purchaseFailed = 'PROPERTY_PURCHASE_FAILED',
    transferFailed = 'PROPERTY_TRANSFER_FAILED',
    leaseNotFound = 'PROPERTY_LEASE_NOT_FOUND',
    leaseAlreadyActive = 'PROPERTY_LEASE_ALREADY_ACTIVE',
    leaseOverdue = 'PROPERTY_LEASE_OVERDUE',
    leaseTerminated = 'PROPERTY_LEASE_TERMINATED',
    rentPaymentFailed = 'PROPERTY_RENT_PAYMENT_FAILED',
    residentLimitReached = 'PROPERTY_RESIDENT_LIMIT_REACHED',
    residentAlreadyExists = 'PROPERTY_RESIDENT_ALREADY_EXISTS',
    residentNotFound = 'PROPERTY_RESIDENT_NOT_FOUND',
    reasonRequired = 'PROPERTY_REASON_REQUIRED',
    versionConflict = 'PROPERTY_VERSION_CONFLICT',
    invalidInput = 'PROPERTY_INVALID_INPUT',
    databaseError = 'PROPERTY_DATABASE_ERROR'
}
