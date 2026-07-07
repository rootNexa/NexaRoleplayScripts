fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_permissions'
author 'Nexa Roleplay'
description 'Zentrales Rechtesystem fuer Nexa Roleplay'
version '0.2.0'

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'nexa_config',
    'nexa_audit',
    'nexa_logs'
}

shared_scripts {
    '@ox_lib/init.lua',
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
