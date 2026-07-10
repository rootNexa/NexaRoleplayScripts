NEXA_LICENSES = { resourceName = 'nexa_licenses', version = '0.6.0' }
NEXA_LICENSE_TYPES = { driver = 'driver', weapon = 'weapon', hunting = 'hunting', business = 'business', custom = 'custom' }
NEXA_LICENSE_STATUS = { pending = 'pending', active = 'active', suspended = 'suspended', revoked = 'revoked', expired = 'expired' }
NEXA_LICENSE_EVENTS = { issued = 'nexa:internal:licenses:issued', suspended = 'nexa:internal:licenses:suspended', reinstated = 'nexa:internal:licenses:reinstated', revoked = 'nexa:internal:licenses:revoked', expired = 'nexa:internal:licenses:expired', validated = 'nexa:internal:licenses:validated' }
NEXA_LICENSE_ERRORS = { typeNotFound = 'LICENSE_TYPE_NOT_FOUND', licenseNotFound = 'LICENSE_NOT_FOUND', licenseInvalid = 'LICENSE_INVALID', statusInvalid = 'LICENSE_STATUS_INVALID', reasonRequired = 'LICENSE_REASON_REQUIRED', invalidInput = 'LICENSE_INVALID_INPUT', databaseError = 'LICENSE_DATABASE_ERROR' }
