NEXA_CHARACTERS = {
    resourceName = 'nexa_characters',
    version = '0.1.0',
    lifecycle = {
        notSelected = 'not_selected',
        selecting = 'selecting',
        selected = 'selected',
        loading = 'loading',
        active = 'active',
        unloading = 'unloading',
        released = 'released'
    },
    statuses = {
        active = 'active',
        inactive = 'inactive',
        deleted = 'deleted',
        blocked = 'blocked',
        pendingReview = 'pending_review'
    },
    events = {
        selected = 'nexa:internal:characters:selected',
        released = 'nexa:internal:characters:released',
        deleted = 'nexa:internal:characters:deleted'
    },
    callbacks = {
        list = 'nexa:characters:cb:list',
        create = 'nexa:characters:cb:create',
        select = 'nexa:characters:cb:select',
        identityStatus = 'nexa:identity:cb:status'
    },
    errors = {
        notFound = 'CHARACTER_NOT_FOUND',
        limitReached = 'CHARACTER_LIMIT_REACHED',
        slotOccupied = 'CHARACTER_SLOT_OCCUPIED',
        invalidName = 'CHARACTER_INVALID_NAME',
        invalidBirthdate = 'CHARACTER_INVALID_BIRTHDATE',
        invalidHeight = 'CHARACTER_INVALID_HEIGHT',
        invalidWeight = 'CHARACTER_INVALID_WEIGHT',
        notOwned = 'CHARACTER_NOT_OWNED',
        alreadyActive = 'CHARACTER_ALREADY_ACTIVE',
        selectionInProgress = 'CHARACTER_SELECTION_IN_PROGRESS',
        blocked = 'CHARACTER_BLOCKED',
        deleted = 'CHARACTER_DELETED',
        updateForbidden = 'CHARACTER_UPDATE_FORBIDDEN',
        deleteForbidden = 'CHARACTER_DELETE_FORBIDDEN',
        invalidInput = 'INVALID_INPUT',
        accountNotReady = 'ACCOUNT_NOT_READY',
        database = 'DATABASE_ERROR'
    }
}
