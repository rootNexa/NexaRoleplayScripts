fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_locales'
author 'Nexa Roleplay'
description 'Zentrale deutsche Sprachverwaltung fuer Nexa Roleplay'
version '0.2.0'

dependencies {
    'nexa_config'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'locales/de.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    'config/server.lua',
    'server/main.lua'
}
