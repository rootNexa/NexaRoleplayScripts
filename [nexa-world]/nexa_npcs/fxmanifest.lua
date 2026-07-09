fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_npcs'
author 'Nexa Roleplay'
description 'NPC- und Interaction-Registry fuer Nexa Roleplay'
version '0.10.5'

dependencies {
    'nexa_api',
    'nexa_featureflags',
    'nexa_security',
    'nexa_permissions',
    'nexa_audit',
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
    'server/validators.lua',
    'server/main.lua',
    'server/callbacks.lua'
}
