fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_furniture'
author 'Nexa Roleplay'
description 'Property Furniture foundation mit serverseitiger Platzierung, Speicherung und Zugriffskontrolle'
version '0.7.0'

dependencies {
    'ox_lib',
    'nexa_api',
    'nexa_security',
    'nexa_audit',
    'nexa_logs'
}

shared_scripts {
    '@ox_lib/init.lua',
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
    'server/main.lua',
    'server/callbacks.lua'
}
