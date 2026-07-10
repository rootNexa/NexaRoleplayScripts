NexaPermissionsConfig = {
    MaxPermissionLength = 128,
    MaxRoleNameLength = 64,
    DevMode = GetConvar('nexa:environment', 'development') == 'development',
    AcePrefix = 'nexa.',
    AllowAceFallback = true,
    BootstrapOwnerAce = 'nexa.permissions.bootstrap_owner'
}
