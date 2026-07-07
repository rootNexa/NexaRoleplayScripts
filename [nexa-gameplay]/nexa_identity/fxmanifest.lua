fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_identity'
author 'Nexa Roleplay'
description 'Charakter- und Identitaetsverwaltung fuer Phase 4A'
version '0.4.0'

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'nexa_api',
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
    'client/main.lua',
    'client/events.lua'
}

server_scripts {
    'config/server.lua',
    'server/validators.lua',
    'server/callbacks.lua',
    'server/events.lua',
    'server/main.lua'
}
