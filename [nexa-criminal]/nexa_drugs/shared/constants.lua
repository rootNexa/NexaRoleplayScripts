NEXA_DRUGS = { resourceName = 'nexa_drugs', version = '0.1.0' }

NEXA_DRUG_TYPES = {
    botanical = 'botanical',
    synthetic = 'synthetic',
    processed = 'processed',
    prescription_abuse = 'prescription_abuse',
    custom = 'custom'
}

NEXA_DRUG_EVENTS = {
    growStarted = 'nexa:internal:drugs:growStarted',
    harvested = 'nexa:internal:drugs:harvested',
    processingStarted = 'nexa:internal:drugs:processingStarted',
    batchCompleted = 'nexa:internal:drugs:batchCompleted'
}

NEXA_DRUG_ERRORS = {
    definitionNotFound = 'DRUG_DEFINITION_NOT_FOUND',
    growSiteNotFound = 'DRUG_GROW_SITE_NOT_FOUND',
    growSiteAccessDenied = 'DRUG_GROW_SITE_ACCESS_DENIED',
    growNotReady = 'DRUG_GROW_NOT_READY',
    batchNotFound = 'DRUG_BATCH_NOT_FOUND',
    batchInvalid = 'DRUG_BATCH_INVALID',
    processingNotFound = 'DRUG_PROCESSING_NOT_FOUND',
    processingAlreadyCompleted = 'DRUG_PROCESSING_ALREADY_COMPLETED',
    qualityInvalid = 'DRUG_QUALITY_INVALID',
    inputMissing = 'DRUG_INPUT_MISSING',
    outputCapacity = 'DRUG_OUTPUT_CAPACITY',
    invalidInput = 'DRUG_INVALID_INPUT',
    databaseError = 'DRUG_DATABASE_ERROR'
}
