fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_interiors'
author 'Nexa Roleplay'
description 'MLO- und Interior-Registry fuer Nexa Roleplay'
version '0.10.3'

dependencies {
    'ox_lib',
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
    'server/callbacks.lua'
}
