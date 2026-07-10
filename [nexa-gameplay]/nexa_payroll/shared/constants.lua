NEXA_PAYROLL = { resourceName = 'nexa_payroll', version = '0.1.0' }

NEXA_PAYROLL_POLICY_STATUS = {
    draft = 'draft',
    active = 'active',
    suspended = 'suspended',
    expired = 'expired',
    deleted = 'deleted'
}

NEXA_PAYROLL_PERIOD_STATUS = {
    open = 'open',
    calculating = 'calculating',
    ready = 'ready',
    processing = 'processing',
    completed = 'completed',
    failed = 'failed',
    manualReview = 'manual_review'
}

NEXA_PAYROLL_RUN_STATUS = {
    created = 'created',
    calculating = 'calculating',
    fundsReserved = 'funds_reserved',
    paying = 'paying',
    completed = 'completed',
    partial = 'partial',
    failed = 'failed',
    compensating = 'compensating',
    manualReview = 'manual_review',
    cancelled = 'cancelled'
}

NEXA_PAYROLL_ENTRY_STATUS = {
    calculated = 'calculated',
    skipped = 'skipped',
    paid = 'paid',
    failed = 'failed',
    manualReview = 'manual_review'
}

NEXA_PAYROLL_ERRORS = {
    notReady = 'PAYROLL_NOT_READY',
    policyNotFound = 'PAYROLL_POLICY_NOT_FOUND',
    policyInvalid = 'PAYROLL_POLICY_INVALID',
    policyConflict = 'PAYROLL_POLICY_CONFLICT',
    periodNotFound = 'PAYROLL_PERIOD_NOT_FOUND',
    periodOverlap = 'PAYROLL_PERIOD_OVERLAP',
    periodAlreadyClosed = 'PAYROLL_PERIOD_ALREADY_CLOSED',
    runNotFound = 'PAYROLL_RUN_NOT_FOUND',
    runAlreadyExists = 'PAYROLL_RUN_ALREADY_EXISTS',
    runAlreadyCompleted = 'PAYROLL_RUN_ALREADY_COMPLETED',
    runInProgress = 'PAYROLL_RUN_IN_PROGRESS',
    dutyInsufficient = 'PAYROLL_DUTY_INSUFFICIENT',
    noPolicy = 'PAYROLL_NO_POLICY',
    organizationInactive = 'PAYROLL_ORGANIZATION_INACTIVE',
    fundsInsufficient = 'PAYROLL_ORGANIZATION_FUNDS_INSUFFICIENT',
    entryNotFound = 'PAYROLL_ENTRY_NOT_FOUND',
    entryAlreadyPaid = 'PAYROLL_ENTRY_ALREADY_PAID',
    calculationFailed = 'PAYROLL_CALCULATION_FAILED',
    paymentFailed = 'PAYROLL_PAYMENT_FAILED',
    compensationFailed = 'PAYROLL_COMPENSATION_FAILED',
    reviewRequired = 'PAYROLL_REVIEW_REQUIRED',
    reasonRequired = 'PAYROLL_REASON_REQUIRED',
    accessDenied = 'PAYROLL_ACCESS_DENIED',
    invalidInput = 'PAYROLL_INVALID_INPUT',
    databaseError = 'PAYROLL_DATABASE_ERROR'
}

NEXA_PAYROLL_EVENTS = {
    periodClosed = 'nexa:internal:payroll:periodClosed',
    runCreated = 'nexa:internal:payroll:runCreated',
    runCompleted = 'nexa:internal:payroll:runCompleted',
    runFailed = 'nexa:internal:payroll:runFailed',
    entryPaid = 'nexa:internal:payroll:entryPaid',
    entryFailed = 'nexa:internal:payroll:entryFailed',
    reviewRequired = 'nexa:internal:payroll:reviewRequired'
}
