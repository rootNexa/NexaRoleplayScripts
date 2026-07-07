fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_evidence'
author 'Nexa Roleplay'
description 'Evidence Core fuer forensische Beweismittel'
version '0.9.0'

dependencies {
    'ox_lib',
    'ox_inventory',
    'nexa_api',
    'nexa_featureflags',
    'nexa_security',
    'nexa_permissions',
    'nexa_audit',
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
    'server/main.lua',
    'server/callbacks.lua',
    'server/events.lua'
}
