NEXA_ORGANIZATIONS = {
    resourceName = 'nexa_organizations',
    version = '0.1.0'
}

NEXA_ORGANIZATION_STATUS = {
    draft = 'draft',
    active = 'active',
    suspended = 'suspended',
    disabled = 'disabled',
    archived = 'archived',
    deleted = 'deleted'
}

NEXA_ORGANIZATION_MEMBER_STATUS = {
    invited = 'invited',
    active = 'active',
    suspended = 'suspended',
    left = 'left',
    removed = 'removed',
    fired = 'fired'
}

NEXA_ORGANIZATION_INVITATION_STATUS = {
    pending = 'pending',
    accepted = 'accepted',
    declined = 'declined',
    revoked = 'revoked',
    expired = 'expired'
}

NEXA_ORGANIZATION_MODULES = {
    mdt = true,
    dispatch = true,
    garage = true,
    storage = true,
    billing = true,
    evidence = true,
    armory = true,
    medical = true,
    documents = true,
    radio = true,
    impound = true,
    licenses = true,
    recruitment = true
}

NEXA_ORGANIZATION_PERMISSIONS = {
    membersView = 'organization.members.view',
    membersInvite = 'organization.members.invite',
    membersRemove = 'organization.members.remove',
    membersPromote = 'organization.members.promote',
    membersDemote = 'organization.members.demote',
    ranksManage = 'organization.ranks.manage',
    accountView = 'organization.account.view',
    accountDebit = 'organization.account.debit',
    accountCredit = 'organization.account.credit',
    storageView = 'organization.storage.view',
    storageModify = 'organization.storage.modify',
    garageUse = 'organization.garage.use',
    garageManage = 'organization.garage.manage',
    dutyUse = 'organization.duty.use',
    billingCreate = 'organization.billing.create',
    mdtUse = 'organization.mdt.use',
    dispatchUse = 'organization.dispatch.use',
    armoryUse = 'organization.armory.use',
    recruitmentManage = 'organization.recruitment.manage'
}

NEXA_ORGANIZATION_ERRORS = {
    notFound = 'ORGANIZATION_NOT_FOUND',
    alreadyExists = 'ORGANIZATION_ALREADY_EXISTS',
    nameInvalid = 'ORGANIZATION_NAME_INVALID',
    typeInvalid = 'ORGANIZATION_TYPE_INVALID',
    statusInvalid = 'ORGANIZATION_STATUS_INVALID',
    notActive = 'ORGANIZATION_NOT_ACTIVE',
    suspended = 'ORGANIZATION_SUSPENDED',
    rankNotFound = 'ORGANIZATION_RANK_NOT_FOUND',
    rankLimitMin = 'ORGANIZATION_RANK_LIMIT_MIN',
    rankLimitMax = 'ORGANIZATION_RANK_LIMIT_MAX',
    ownerRankRequired = 'ORGANIZATION_OWNER_RANK_REQUIRED',
    hierarchyForbidden = 'ORGANIZATION_HIERARCHY_FORBIDDEN',
    memberNotFound = 'ORGANIZATION_MEMBER_NOT_FOUND',
    memberAlreadyExists = 'ORGANIZATION_MEMBER_ALREADY_EXISTS',
    characterAlreadyAssigned = 'ORGANIZATION_CHARACTER_ALREADY_ASSIGNED',
    invitationNotFound = 'ORGANIZATION_INVITATION_NOT_FOUND',
    invitationExpired = 'ORGANIZATION_INVITATION_EXPIRED',
    invitationForbidden = 'ORGANIZATION_INVITATION_FORBIDDEN',
    permissionDenied = 'ORGANIZATION_PERMISSION_DENIED',
    reasonRequired = 'ORGANIZATION_REASON_REQUIRED',
    moduleNotFound = 'ORGANIZATION_MODULE_NOT_FOUND',
    moduleInvalid = 'ORGANIZATION_MODULE_INVALID',
    invalidInput = 'ORGANIZATION_INVALID_INPUT',
    databaseError = 'ORGANIZATION_DATABASE_ERROR'
}

NEXA_ORGANIZATION_EVENTS = {
    created = 'nexa:internal:organization:created',
    activated = 'nexa:internal:organization:activated',
    suspended = 'nexa:internal:organization:suspended',
    memberJoined = 'nexa:internal:organization:memberJoined',
    memberLeft = 'nexa:internal:organization:memberLeft',
    memberRankChanged = 'nexa:internal:organization:memberRankChanged',
    moduleEnabled = 'nexa:internal:organization:moduleEnabled'
}
