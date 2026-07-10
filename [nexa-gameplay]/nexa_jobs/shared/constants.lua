NEXA_JOBS = {
    resourceName = 'nexa_jobs',
    version = '0.1.0'
}

NEXA_JOB_STATES = {
    unassigned = 'unassigned',
    assigned = 'assigned',
    offDuty = 'off_duty',
    onDuty = 'on_duty',
    suspended = 'suspended',
    unloading = 'unloading'
}

NEXA_DUTY_SESSION_STATUS = {
    active = 'active',
    ended = 'ended',
    forceStopped = 'force_stopped'
}

NEXA_JOB_ERRORS = {
    notAssigned = 'JOB_NOT_ASSIGNED',
    notReady = 'JOB_NOT_READY',
    dutyNotAllowed = 'JOB_DUTY_NOT_ALLOWED',
    alreadyOnDuty = 'JOB_ALREADY_ON_DUTY',
    notOnDuty = 'JOB_NOT_ON_DUTY',
    memberSuspended = 'JOB_MEMBER_SUSPENDED',
    organizationSuspended = 'JOB_ORGANIZATION_SUSPENDED',
    dutySessionConflict = 'JOB_DUTY_SESSION_CONFLICT',
    invalidInput = 'JOB_INVALID_INPUT',
    databaseError = 'JOB_DATABASE_ERROR'
}

NEXA_JOB_EVENTS = {
    ready = 'nexa:internal:job:ready',
    dutyStarted = 'nexa:internal:job:dutyStarted',
    dutyStopped = 'nexa:internal:job:dutyStopped',
    unloading = 'nexa:internal:job:unloading'
}
