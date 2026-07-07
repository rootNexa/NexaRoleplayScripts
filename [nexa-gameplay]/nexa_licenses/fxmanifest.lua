fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_licenses'
author 'Nexa Roleplay'
description 'Lizenzverwaltung fuer Phase 4B'
version '0.4.1'

dependencies {
    'ox_lib',
    'nexa_api',
    'nexa_documents',
    'nexa_permissions',
    'nexa_security',
    'nexa_logs'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'shared/constants.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    'config/server.lua',
    'server/validators.lua',
    'server/callbacks.lua',
    'server/events.lua',
    'server/main.lua'
}
