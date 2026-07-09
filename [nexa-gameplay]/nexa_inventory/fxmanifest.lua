fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_inventory'
author 'Nexa Roleplay'
description 'Foundation fuer serverautoritative Inventare'
version '0.1.0'

dependencies {
    'oxmysql',
    'nexa_api',
    'nexa_logs',
    'nexa_items'
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
