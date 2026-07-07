fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_maps'
author 'Nexa Roleplay'
description 'Map- und MLO-Datei-Registry fuer Nexa Roleplay'
version '0.10.4'

dependencies {
    'ox_lib',
    'nexa_api',
    'nexa_featureflags',
    'nexa_security',
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
    'server/callbacks.lua'
}
