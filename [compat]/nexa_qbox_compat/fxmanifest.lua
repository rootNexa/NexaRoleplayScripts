fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_qbox_compat'
author 'Nexa Roleplay'
description 'Compatibility adapters for Qbox-as-framework-only operation on the Nexa persistence model'
version '0.1.0'

dependencies {
    'oxmysql',
    'ox_lib'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    '@ox_lib/init.lua',
    'client/main.lua'
}
