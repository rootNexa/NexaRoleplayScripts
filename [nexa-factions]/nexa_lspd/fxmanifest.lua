fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_lspd'
author 'Nexa Roleplay'
description 'LSPD Phase 8B auf Basis des Fraktions-Cores'
version '0.8.0'

dependencies {
    'nexa_api',
    'nexa_ui',
    'nexa_featureflags',
    'nexa_security',
    'nexa_permissions',
    'nexa_audit',
    'nexa_logs',
    'nexa_factions_core',
    'nexa_mdt'
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
    'server/validators.lua',
    'server/callbacks.lua',
    'server/events.lua',
    'server/main.lua'
}
