fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_logs'
author 'Nexa Roleplay'
description 'Technische Logs fuer Nexa Roleplay'
version '0.2.0'

dependencies {
    'ox_lib',
    'nexa_config',
    'nexa_locales',
    'nexa_audit'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'shared/constants.lua',
    'shared/format.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    'config/server.lua',
    'server/service.lua',
    'server/main.lua'
}
