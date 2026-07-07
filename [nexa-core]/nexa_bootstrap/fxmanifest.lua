fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_bootstrap'
author 'Nexa Roleplay'
description 'Start- und Dependency-Validierung fuer Nexa Roleplay'
version '0.1.0'

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'nexa_config',
    'nexa_logs'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    'config/server.lua',
    'server/main.lua'
}

server_export 'getStatus'
