NexaPermissionsConfig = {
    DefaultRole = 'user',
    MaxPermissionLength = 96,
    MaxRoleNameLength = 48,
    DevMode = GetConvar('nexa:environment', 'development') == 'development',
    AcePrefix = 'nexa.',
    EnsureRoles = {
        {
            name = 'user',
            label = 'User',
            priority = 0,
            inherits = nil
        },
        {
            name = 'admin',
            label = 'Admin',
            priority = 100,
            inherits = 'user'
        }
    },
    DefaultRules = {
        user = {},
        admin = {
            {
                permission = 'nexa.admin',
                allowed = true
            },
            {
                permission = 'nexa.admin.*',
                allowed = true
            }
        }
    }
}
