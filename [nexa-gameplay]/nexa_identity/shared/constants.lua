NEXA_IDENTITY = {
    resourceName = 'nexa_identity',
    version = '0.5.0',
    events = {
        resolving = 'nexa:internal:identity:resolving',
        ready = 'nexa:internal:identity:ready',
        rejected = 'nexa:internal:identity:rejected',
        statusChanged = 'nexa:internal:identity:statusChanged'
    },
    statuses = {
        active = 'active',
        suspended = 'suspended',
        banned = 'banned',
        disabled = 'disabled',
        pendingReview = 'pending_review'
    },
    errors = {
        accountNotFound = 'ACCOUNT_NOT_FOUND',
        accountNotReady = 'ACCOUNT_NOT_READY',
        accountDisabled = 'ACCOUNT_DISABLED',
        accountSuspended = 'ACCOUNT_SUSPENDED',
        accountBanned = 'ACCOUNT_BANNED',
        identifierMissing = 'IDENTIFIER_MISSING',
        identifierInvalid = 'IDENTIFIER_INVALID',
        resolutionFailed = 'IDENTITY_RESOLUTION_FAILED',
        multiAccountReviewRequired = 'MULTI_ACCOUNT_REVIEW_REQUIRED',
        database = 'DATABASE_ERROR',
        invalidInput = 'INVALID_INPUT'
    }
}
