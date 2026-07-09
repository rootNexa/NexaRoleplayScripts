NEXA_JOBSCREATOR = {
    resourceName = 'nexa_jobscreator',
    version = '0.1.0'
}

NEXA_JOBSCREATOR_TABLES = {
    organizations = 'organizations',
    grades = 'organization_grades',
    members = 'organization_members'
}

NEXA_JOBSCREATOR_ERRORS = {
    duplicateName = 'DUPLICATE_ORGANIZATION_NAME',
    invalidInput = 'INVALID_INPUT',
    invalidType = 'INVALID_ORGANIZATION_TYPE',
    invalidMdtType = 'INVALID_MDT_TYPE',
    notFound = 'ORGANIZATION_NOT_FOUND',
    databaseError = 'DATABASE_ERROR'
}

NEXA_JOBSCREATOR_CALLBACKS = {
    createOrganization = 'nexa:jobscreator:cb:createOrganization',
    getOrganization = 'nexa:jobscreator:cb:getOrganization',
    listOrganizations = 'nexa:jobscreator:cb:listOrganizations',
    setOrganizationEnabled = 'nexa:jobscreator:cb:setOrganizationEnabled'
}
