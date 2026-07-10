NEXA_JOBFRAMEWORK = { resourceName = 'nexa_jobframework', version = '0.1.0' }

NEXA_JOB_TYPES = {
    gathering = 'gathering',
    processing = 'processing',
    delivery = 'delivery',
    transport = 'transport',
    service = 'service',
    route = 'route',
    production = 'production',
    contract = 'contract',
    public_service = 'public_service',
    custom = 'custom'
}

NEXA_JOB_TASK_TYPES = {
    go_to = 'go_to',
    interact = 'interact',
    collect_item = 'collect_item',
    deliver_item = 'deliver_item',
    process_item = 'process_item',
    load_vehicle = 'load_vehicle',
    unload_vehicle = 'unload_vehicle',
    drive_route = 'drive_route',
    transport_passenger = 'transport_passenger',
    repair_vehicle = 'repair_vehicle',
    inspect_vehicle = 'inspect_vehicle',
    wait = 'wait',
    use_station = 'use_station',
    complete_checkpoint = 'complete_checkpoint',
    custom = 'custom'
}

NEXA_JOB_STATUS = { draft = 'draft', active = 'active', suspended = 'suspended', disabled = 'disabled', deprecated = 'deprecated', deleted = 'deleted' }
NEXA_JOB_PHASE_STATUS = { pending = 'pending', active = 'active', completed = 'completed', failed = 'failed', skipped = 'skipped', cancelled = 'cancelled' }
NEXA_JOB_SESSION_STATUS = { created = 'created', starting = 'starting', active = 'active', paused = 'paused', completed = 'completed', failed = 'failed', cancelled = 'cancelled', expired = 'expired', manual_review = 'manual_review' }
NEXA_JOB_MEMBER_STATUS = { active = 'active', left = 'left', removed = 'removed', disconnected = 'disconnected' }
NEXA_JOB_PROGRESS_STATUS = { pending = 'pending', active = 'active', completed = 'completed', failed = 'failed' }
NEXA_JOB_REWARD_STATUS = { pending = 'pending', completed = 'completed', failed = 'failed', compensated = 'compensated', duplicate = 'duplicate' }

NEXA_JOB_EVENTS = {
    definitionCreated = 'nexa:internal:jobframework:definitionCreated',
    sessionCreated = 'nexa:internal:jobframework:sessionCreated',
    sessionStarted = 'nexa:internal:jobframework:sessionStarted',
    phaseStarted = 'nexa:internal:jobframework:phaseStarted',
    taskProgressed = 'nexa:internal:jobframework:taskProgressed',
    taskCompleted = 'nexa:internal:jobframework:taskCompleted',
    sessionCompleted = 'nexa:internal:jobframework:sessionCompleted',
    sessionFailed = 'nexa:internal:jobframework:sessionFailed',
    sessionCancelled = 'nexa:internal:jobframework:sessionCancelled',
    rewardCompleted = 'nexa:internal:jobframework:rewardCompleted',
    rewardFailed = 'nexa:internal:jobframework:rewardFailed',
    cooldownApplied = 'nexa:internal:jobframework:cooldownApplied'
}

NEXA_JOB_CALLBACKS = {
    listAvailable = 'nexa:jobframework:cb:listAvailable',
    getDefinition = 'nexa:jobframework:cb:getDefinition',
    getActiveSession = 'nexa:jobframework:cb:getActiveSession',
    startJob = 'nexa:jobframework:cb:startJob',
    cancelJob = 'nexa:jobframework:cb:cancelJob',
    completeTask = 'nexa:jobframework:cb:completeTask'
}

NEXA_JOB_ERRORS = {
    notReady = 'JOBFRAMEWORK_NOT_READY',
    definitionNotFound = 'JOB_DEFINITION_NOT_FOUND',
    definitionNotActive = 'JOB_DEFINITION_NOT_ACTIVE',
    accessDenied = 'JOB_ACCESS_DENIED',
    dutyRequired = 'JOB_DUTY_REQUIRED',
    organizationRequired = 'JOB_ORGANIZATION_REQUIRED',
    cooldownActive = 'JOB_COOLDOWN_ACTIVE',
    sessionAlreadyActive = 'JOB_SESSION_ALREADY_ACTIVE',
    sessionNotFound = 'JOB_SESSION_NOT_FOUND',
    sessionNotActive = 'JOB_SESSION_NOT_ACTIVE',
    sessionExpired = 'JOB_SESSION_EXPIRED',
    sessionMemberInvalid = 'JOB_SESSION_MEMBER_INVALID',
    groupFull = 'JOB_GROUP_FULL',
    invitationNotFound = 'JOB_INVITATION_NOT_FOUND',
    invitationExpired = 'JOB_INVITATION_EXPIRED',
    phaseNotFound = 'JOB_PHASE_NOT_FOUND',
    phaseInvalidTransition = 'JOB_PHASE_INVALID_TRANSITION',
    taskNotFound = 'JOB_TASK_NOT_FOUND',
    taskNotActive = 'JOB_TASK_NOT_ACTIVE',
    taskValidationFailed = 'JOB_TASK_VALIDATION_FAILED',
    taskAlreadyCompleted = 'JOB_TASK_ALREADY_COMPLETED',
    progressInvalid = 'JOB_PROGRESS_INVALID',
    checkpointInvalid = 'JOB_CHECKPOINT_INVALID',
    resourceNodeNotFound = 'JOB_RESOURCE_NODE_NOT_FOUND',
    resourceNodeDepleted = 'JOB_RESOURCE_NODE_DEPLETED',
    toolRequired = 'JOB_TOOL_REQUIRED',
    vehicleRequired = 'JOB_VEHICLE_REQUIRED',
    cargoInvalid = 'JOB_CARGO_INVALID',
    rewardNotFound = 'JOB_REWARD_NOT_FOUND',
    rewardAlreadyPaid = 'JOB_REWARD_ALREADY_PAID',
    rewardFailed = 'JOB_REWARD_FAILED',
    rewardCompensationFailed = 'JOB_REWARD_COMPENSATION_FAILED',
    reasonRequired = 'JOB_REASON_REQUIRED',
    rateLimited = 'JOB_RATE_LIMITED',
    invalidInput = 'JOB_INVALID_INPUT',
    databaseError = 'JOB_DATABASE_ERROR'
}
