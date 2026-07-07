fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_government'
author 'Nexa Roleplay'
description 'Government Phase 8D auf Basis des Fraktions-Cores'
version '0.8.0'

dependencies {
    'ox_lib',
    'nexa_api',
    'nexa_featureflags',
    'nexa_security',
    'nexa_permissions',
    'nexa_audit',
    'nexa_logs',
    'nexa_factions_core',
    'nexa_documents',
    'nexa_licenses'
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
