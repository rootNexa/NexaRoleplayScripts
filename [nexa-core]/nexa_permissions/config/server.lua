NexaPermissionsServer = {
    CommandsEnabled = NexaPermissionsConfig.DevMode,
    CommandPermission = 'nexa.permissions.view',
    BootstrapOwnerEnabled = GetConvar('nexa:permissions:bootstrapOwner', 'false') == 'true',
    BootstrapOwnerAce = NexaPermissionsConfig.BootstrapOwnerAce
}
