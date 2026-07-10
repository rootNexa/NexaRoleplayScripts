NEXA_PERMISSIONS = {
    resourceName = 'nexa_permissions',
    version = '1.0.0',
    errors = {
        permissionNotFound = 'PERMISSION_NOT_FOUND',
        roleNotFound = 'ROLE_NOT_FOUND',
        roleAlreadyAssigned = 'ROLE_ALREADY_ASSIGNED',
        roleNotAssigned = 'ROLE_NOT_ASSIGNED',
        permissionAlreadyGranted = 'PERMISSION_ALREADY_GRANTED',
        permissionAlreadyDenied = 'PERMISSION_ALREADY_DENIED',
        permissionNotAssigned = 'PERMISSION_NOT_ASSIGNED',
        roleHierarchyForbidden = 'ROLE_HIERARCHY_FORBIDDEN',
        ownerProtection = 'OWNER_PROTECTION',
        lastOwnerProtection = 'LAST_OWNER_PROTECTION',
        selfElevationForbidden = 'SELF_ELEVATION_FORBIDDEN',
        roleInheritanceCycle = 'ROLE_INHERITANCE_CYCLE',
        actorNotAuthorized = 'ACTOR_NOT_AUTHORIZED',
        targetNotFound = 'TARGET_NOT_FOUND',
        auditReasonRequired = 'AUDIT_REASON_REQUIRED'
    },
    adminDutyStates = {
        off_duty = true,
        on_duty = true,
        suspended = true
    },
    roleLevels = {
        support_trainee = 10,
        supporter = 20,
        head_support = 30,
        trial_admin = 40,
        admin = 50,
        senior_admin = 60,
        head_admin = 70,
        co_owner = 90,
        owner = 100,
        qa_tester = 15,
        developer = 35
    }
}

NEXA_PERMISSIONS.catalog = {
    { name = 'nexa.core.health.view', category = 'core', label = 'View Core Health' },
    { name = 'nexa.core.logs.view', category = 'core', label = 'View Core Logs' },
    { name = 'nexa.core.modules.view', category = 'core', label = 'View Core Modules' },

    { name = 'nexa.accounts.view', category = 'accounts', label = 'View Accounts' },
    { name = 'nexa.accounts.status.view', category = 'accounts', label = 'View Account Status' },
    { name = 'nexa.accounts.status.change', category = 'accounts', label = 'Change Account Status', critical = true },
    { name = 'nexa.accounts.review.view', category = 'accounts', label = 'View Account Reviews' },
    { name = 'nexa.accounts.review.resolve', category = 'accounts', label = 'Resolve Account Reviews' },

    { name = 'nexa.characters.view', category = 'characters', label = 'View Character' },
    { name = 'nexa.characters.view_all', category = 'characters', label = 'View All Characters' },
    { name = 'nexa.characters.update', category = 'characters', label = 'Update Characters', critical = true },
    { name = 'nexa.characters.delete', category = 'characters', label = 'Delete Characters', critical = true },
    { name = 'nexa.characters.restore', category = 'characters', label = 'Restore Characters', critical = true },
    { name = 'nexa.characters.block', category = 'characters', label = 'Block Characters', critical = true },

    { name = 'nexa.admin.panel', category = 'admin', label = 'Open Admin Panel' },
    { name = 'nexa.admin.duty', category = 'admin', label = 'Use Admin Duty' },
    { name = 'nexa.admin.teleport', category = 'admin', label = 'Teleport', dutyRequired = true },
    { name = 'nexa.admin.noclip', category = 'admin', label = 'Noclip', dutyRequired = true },
    { name = 'nexa.admin.spectate', category = 'admin', label = 'Spectate', dutyRequired = true },
    { name = 'nexa.admin.freeze', category = 'admin', label = 'Freeze Player', dutyRequired = true },
    { name = 'nexa.admin.revive', category = 'admin', label = 'Revive Player', dutyRequired = true },
    { name = 'nexa.admin.heal', category = 'admin', label = 'Heal Player', dutyRequired = true },
    { name = 'nexa.admin.kick', category = 'admin', label = 'Kick Player', dutyRequired = true },
    { name = 'nexa.admin.warn', category = 'admin', label = 'Warn Player', dutyRequired = true },
    { name = 'nexa.admin.ban.temp', category = 'admin', label = 'Temporary Ban', critical = true },
    { name = 'nexa.admin.ban.permanent', category = 'admin', label = 'Permanent Ban', critical = true },
    { name = 'nexa.admin.unban', category = 'admin', label = 'Unban Player', critical = true },
    { name = 'nexa.admin.inventory.view', category = 'admin', label = 'View Inventory', dutyRequired = true },
    { name = 'nexa.admin.inventory.modify', category = 'admin', label = 'Modify Inventory', critical = true },
    { name = 'nexa.admin.money.view', category = 'admin', label = 'View Money', dutyRequired = true },
    { name = 'nexa.admin.money.modify', category = 'admin', label = 'Modify Money', critical = true },
    { name = 'nexa.admin.vehicle.view', category = 'admin', label = 'View Vehicle', dutyRequired = true },
    { name = 'nexa.admin.vehicle.modify', category = 'admin', label = 'Modify Vehicle', critical = true },
    { name = 'nexa.admin.character.view', category = 'admin', label = 'View Admin Character Data', dutyRequired = true },
    { name = 'nexa.admin.character.modify', category = 'admin', label = 'Modify Admin Character Data', critical = true },
    { name = 'nexa.admin.logs.view', category = 'admin', label = 'View Admin Logs' },
    { name = 'nexa.admin.audit.view', category = 'admin', label = 'View Admin Audit' },

    { name = 'nexa.support.panel', category = 'support', label = 'Open Support Panel' },
    { name = 'nexa.support.ticket.view', category = 'support', label = 'View Tickets' },
    { name = 'nexa.support.ticket.claim', category = 'support', label = 'Claim Tickets' },
    { name = 'nexa.support.ticket.close', category = 'support', label = 'Close Tickets' },
    { name = 'nexa.support.teleport', category = 'support', label = 'Support Teleport', dutyRequired = true },
    { name = 'nexa.support.freeze', category = 'support', label = 'Support Freeze', dutyRequired = true },
    { name = 'nexa.support.revive', category = 'support', label = 'Support Revive', dutyRequired = true },
    { name = 'nexa.support.player.view', category = 'support', label = 'View Support Player Data' },
    { name = 'nexa.support.notes.view', category = 'support', label = 'View Support Notes' },
    { name = 'nexa.support.notes.create', category = 'support', label = 'Create Support Notes' },

    { name = 'nexa.permissions.view', category = 'permissions', label = 'View Permissions' },
    { name = 'nexa.permissions.assign_role', category = 'permissions', label = 'Assign Roles', critical = true },
    { name = 'nexa.permissions.remove_role', category = 'permissions', label = 'Remove Roles', critical = true },
    { name = 'nexa.permissions.grant', category = 'permissions', label = 'Grant Permissions', critical = true },
    { name = 'nexa.permissions.deny', category = 'permissions', label = 'Deny Permissions', critical = true },
    { name = 'nexa.permissions.revoke', category = 'permissions', label = 'Revoke Permissions', critical = true },
    { name = 'nexa.permissions.audit', category = 'permissions', label = 'View Permission Audit' },
    { name = 'nexa.permissions.manage_owner', category = 'permissions', label = 'Manage Owner Role', critical = true }
}

NEXA_PERMISSIONS.roles = {
    { name = 'support_trainee', label = 'Support Trainee', description = 'Supervised support role.' },
    { name = 'supporter', label = 'Supporter', description = 'Support ticket handling.', inherits = 'support_trainee' },
    { name = 'head_support', label = 'Head Support', description = 'Support team lead.', inherits = 'supporter' },

    { name = 'trial_admin', label = 'Trial Admin', description = 'Limited administration.' },
    { name = 'admin', label = 'Admin', description = 'Standard administration.', inherits = 'trial_admin' },
    { name = 'senior_admin', label = 'Senior Admin', description = 'Senior administration.', inherits = 'admin' },
    { name = 'head_admin', label = 'Head Admin', description = 'Admin team lead.', inherits = 'senior_admin' },
    { name = 'co_owner', label = 'Co-Owner', description = 'Project leadership without owner override.', inherits = 'head_admin' },
    { name = 'owner', label = 'Owner', description = 'Protected project owner.', inherits = 'co_owner' },

    { name = 'developer', label = 'Developer', description = 'Technical diagnostics role.' },
    { name = 'qa_tester', label = 'QA Tester', description = 'Quality-assurance diagnostics role.' }
}

NEXA_PERMISSIONS.rolePermissions = {
    support_trainee = {
        'nexa.support.panel',
        'nexa.support.ticket.view',
        'nexa.support.ticket.claim',
        'nexa.support.player.view'
    },
    supporter = {
        'nexa.support.ticket.close',
        'nexa.support.teleport',
        'nexa.support.freeze',
        'nexa.support.revive',
        'nexa.support.notes.view',
        'nexa.support.notes.create'
    },
    head_support = {
        'nexa.permissions.audit',
        'nexa.admin.duty'
    },
    trial_admin = {
        'nexa.admin.panel',
        'nexa.admin.duty',
        'nexa.admin.teleport',
        'nexa.admin.freeze',
        'nexa.admin.revive',
        'nexa.admin.warn',
        'nexa.admin.character.view',
        'nexa.characters.view'
    },
    admin = {
        'nexa.admin.spectate',
        'nexa.admin.kick',
        'nexa.admin.ban.temp',
        'nexa.admin.inventory.view',
        'nexa.admin.money.view',
        'nexa.admin.vehicle.view',
        'nexa.support.ticket.close'
    },
    senior_admin = {
        'nexa.admin.inventory.modify',
        'nexa.admin.money.modify',
        'nexa.admin.vehicle.modify',
        'nexa.admin.character.modify',
        'nexa.admin.unban',
        'nexa.characters.view_all',
        'nexa.characters.update',
        'nexa.characters.restore',
        'nexa.characters.block'
    },
    head_admin = {
        'nexa.admin.ban.permanent',
        'nexa.admin.logs.view',
        'nexa.admin.audit.view',
        'nexa.permissions.view',
        'nexa.permissions.assign_role',
        'nexa.permissions.remove_role',
        'nexa.permissions.audit'
    },
    co_owner = {
        'nexa.core.health.view',
        'nexa.core.logs.view',
        'nexa.core.modules.view',
        'nexa.accounts.view',
        'nexa.accounts.status.view',
        'nexa.accounts.status.change',
        'nexa.accounts.review.view',
        'nexa.accounts.review.resolve',
        'nexa.characters.delete',
        'nexa.permissions.grant',
        'nexa.permissions.deny',
        'nexa.permissions.revoke'
    },
    owner = {
        'nexa.permissions.manage_owner'
    },
    developer = {
        'nexa.core.health.view',
        'nexa.core.logs.view',
        'nexa.core.modules.view'
    },
    qa_tester = {
        'nexa.core.health.view'
    }
}
