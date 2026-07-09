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
    gradeNotFound = 'GRADE_NOT_FOUND',
    memberNotFound = 'MEMBER_NOT_FOUND',
    notFound = 'ORGANIZATION_NOT_FOUND',
    databaseError = 'DATABASE_ERROR'
}

NEXA_JOBSCREATOR_CALLBACKS = {
    createOrganization = 'nexa:jobscreator:cb:createOrganization',
    getOrganization = 'nexa:jobscreator:cb:getOrganization',
    listOrganizations = 'nexa:jobscreator:cb:listOrganizations',
    setOrganizationEnabled = 'nexa:jobscreator:cb:setOrganizationEnabled',
    createGrade = 'nexa:jobscreator:cb:createGrade',
    listGrades = 'nexa:jobscreator:cb:listGrades',
    updateGrade = 'nexa:jobscreator:cb:updateGrade',
    deleteGrade = 'nexa:jobscreator:cb:deleteGrade',
    addMember = 'nexa:jobscreator:cb:addMember',
    listMembers = 'nexa:jobscreator:cb:listMembers',
    updateMember = 'nexa:jobscreator:cb:updateMember',
    removeMember = 'nexa:jobscreator:cb:removeMember',
    setDuty = 'nexa:jobscreator:cb:setDuty'
}
