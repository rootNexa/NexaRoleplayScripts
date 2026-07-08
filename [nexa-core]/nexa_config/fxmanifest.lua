fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_config'
author 'Nexa Roleplay'
description 'Zentrale Projektkonfiguration fuer Nexa Roleplay'
version '0.2.0'

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua',
    'shared/utils.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    'config/server.lua',
    'server/main.lua'
}
