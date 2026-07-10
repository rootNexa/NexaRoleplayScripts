NEXA_MDT_MESSAGES = {
    init = 'mdt:init',
    visibility = 'mdt:visibility',
    snapshot = 'mdt:snapshot',
    searchResult = 'mdt:searchResult',
    notice = 'mdt:notice'
}

NEXA_MDT_NUI = {
    ready = 'nexaMdtReady',
    close = 'nexaMdtClose',
    refresh = 'nexaMdtRefresh',
    searchPerson = 'nexaMdtSearchPerson'
}

NEXA_MDT_RECORD_STATUS = { draft = 'draft', submitted = 'submitted', finalized = 'finalized', amended = 'amended', archived = 'archived' }
NEXA_MDT_WARRANT_STATUS = { draft = 'draft', requested = 'requested', approved = 'approved', active = 'active', served = 'served', rejected = 'rejected', expired = 'expired', cancelled = 'cancelled' }
NEXA_MDT_EVENTS = { caseCreated = 'nexa:internal:mdt:caseCreated', reportCreated = 'nexa:internal:mdt:reportCreated', warrantCreated = 'nexa:internal:mdt:warrantCreated', boloCreated = 'nexa:internal:mdt:boloCreated' }
NEXA_MDT_ERRORS = { invalidInput = 'MDT_INVALID_INPUT', notFound = 'MDT_NOT_FOUND', invalidState = 'MDT_INVALID_STATE', databaseError = 'MDT_DATABASE_ERROR' }
