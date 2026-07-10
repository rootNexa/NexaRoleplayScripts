fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_permissions'
author 'Nexa Roleplay'
description 'Eigenes Rollen- und Rechtesystem fuer Nexa Framework'
version '1.0.0'

dependencies {
    'nexa-core',
    'nexa_identity'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua',
    'shared/validators.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    'config/server.lua',
    'server/service.lua',
    'server/main.lua'
}

server_exports {
    'Has',
    'HasAny',
    'HasAll',
    'GetPermissions',
    'GetRoles',
    'GetDecisionTrace',
    'GetRole',
    'ListRoles',
    'ListRegisteredPermissions',
    'AssignRole',
    'RemoveRole',
    'GrantPermission',
    'DenyPermission',
    'RevokePermission',
    'RegisterPermission',
    'RegisterRole',
    'SetRoleInheritance',
    'SetAdminDuty',
    'GetAdminDuty',
    'IsAdminOnDuty',
    'ClearAdminDuty',
    'AssignRoleToPlayer',
    'RemoveRoleFromPlayer',
    'ReloadPermissions',
    'GetPermissionCache'
}
