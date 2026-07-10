NexaOrganizationsConfig = {
    autoMigrate = true,
    minRanks = 5,
    maxRanks = 15,
    invitationTtlSeconds = 604800,
    permissions = {
        view = 'nexa.organizations.view',
        create = 'nexa.organizations.create',
        update = 'nexa.organizations.update',
        publish = 'nexa.organizations.publish',
        suspend = 'nexa.organizations.suspend',
        archive = 'nexa.organizations.archive',
        delete = 'nexa.organizations.delete',
        membersManage = 'nexa.organizations.members.manage',
        ranksManage = 'nexa.organizations.ranks.manage',
        modulesManage = 'nexa.organizations.modules.manage',
        accountsManage = 'nexa.organizations.accounts.manage',
        storagesManage = 'nexa.organizations.storages.manage',
        garagesManage = 'nexa.organizations.garages.manage'
    }
}
