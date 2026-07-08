fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_permissions'
author 'Nexa Roleplay'
description 'Eigenes Rollen- und Rechtesystem fuer Nexa Framework'
version '0.3.0'

dependencies {
    'oxmysql',
    'nexa-lib',
    'nexa-core'
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
    '@oxmysql/lib/MySQL.lua',
    'config/server.lua',
    'server/service.lua',
    'server/main.lua'
}

server_exports {
    'Has',
    'HasAny',
    'HasAll',
    'GetRoles',
    'AssignRoleToPlayer',
    'RemoveRoleFromPlayer',
    'ReloadPermissions',
    'GetPermissionCache'
}
