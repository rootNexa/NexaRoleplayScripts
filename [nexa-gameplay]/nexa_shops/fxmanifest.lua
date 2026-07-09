fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_shops'
author 'Nexa Roleplay'
description 'Foundation fuer generische Shops und Nexa Shop Studio'
version '0.1.0'

dependencies {
    'oxmysql',
    'nexa_api',
    'nexa_logs'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/main.lua'
}
