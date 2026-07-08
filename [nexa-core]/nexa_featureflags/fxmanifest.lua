fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_featureflags'
author 'Nexa Roleplay'
description 'Feature-Schalter fuer Nexa Roleplay'
version '0.2.0'

dependencies {
    'oxmysql',
    'nexa_config'
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
    'server/main.lua'
}
