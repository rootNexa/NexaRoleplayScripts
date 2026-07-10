NEXA_BILLING = { resourceName = 'nexa_billing', version = '0.1.0' }

NEXA_INVOICE_STATUS = {
    draft = 'draft',
    issued = 'issued',
    viewed = 'viewed',
    partiallyPaid = 'partially_paid',
    paid = 'paid',
    overdue = 'overdue',
    cancelled = 'cancelled',
    credited = 'credited',
    disputed = 'disputed',
    failed = 'failed'
}

NEXA_INVOICE_PAYMENT_STATUS = {
    pending = 'pending',
    completed = 'completed',
    failed = 'failed'
}

NEXA_BILLING_ERRORS = {
    notFound = 'INVOICE_NOT_FOUND',
    statusInvalid = 'INVOICE_STATUS_INVALID',
    amountInvalid = 'INVOICE_AMOUNT_INVALID',
    itemsInvalid = 'INVOICE_ITEMS_INVALID',
    recipientInvalid = 'INVOICE_RECIPIENT_INVALID',
    issuerInvalid = 'INVOICE_ISSUER_INVALID',
    accessDenied = 'INVOICE_ACCESS_DENIED',
    alreadyPaid = 'INVOICE_ALREADY_PAID',
    cancelled = 'INVOICE_CANCELLED',
    overdue = 'INVOICE_OVERDUE',
    paymentFailed = 'INVOICE_PAYMENT_FAILED',
    paymentDuplicate = 'INVOICE_PAYMENT_DUPLICATE',
    overpayment = 'INVOICE_OVERPAYMENT',
    cancelForbidden = 'INVOICE_CANCEL_FORBIDDEN',
    creditInvalid = 'INVOICE_CREDIT_INVALID',
    disputeInvalid = 'INVOICE_DISPUTE_INVALID',
    reasonRequired = 'INVOICE_REASON_REQUIRED',
    rateLimited = 'INVOICE_RATE_LIMITED',
    invalidInput = 'INVOICE_INVALID_INPUT',
    databaseError = 'INVOICE_DATABASE_ERROR'
}

NEXA_BILLING_EVENTS = {
    invoiceCreated = 'nexa:internal:billing:invoiceCreated',
    invoiceViewed = 'nexa:internal:billing:invoiceViewed',
    invoicePaid = 'nexa:internal:billing:invoicePaid',
    invoiceCancelled = 'nexa:internal:billing:invoiceCancelled',
    invoiceOverdue = 'nexa:internal:billing:invoiceOverdue',
    invoiceDisputed = 'nexa:internal:billing:invoiceDisputed',
    creditCreated = 'nexa:internal:billing:creditCreated'
}
