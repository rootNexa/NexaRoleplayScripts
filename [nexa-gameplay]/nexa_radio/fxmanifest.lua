fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_radio'
author 'Nexa Roleplay'
description 'Server-authoritative radio channel and frequency foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_api',
    'nexa_dispatch'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua'
}

server_scripts {
    'server/database.lua',
    'server/main.lua'
}

server_exports {
    'RegisterChannel',
    'JoinChannel',
    'LeaveChannel',
    'SetPriority',
    'ListChannels',
    'getSchema',
    'getStatus'
}
