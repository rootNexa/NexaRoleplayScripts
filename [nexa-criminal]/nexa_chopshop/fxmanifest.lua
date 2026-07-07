fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_chopshop'
author 'Nexa Roleplay'
description 'Servervalidierter Chopshop fuer Fahrzeugzerlegung, Teile und Verkauf'
version '0.1.0'

dependencies {
    'ox_lib',
    'nexa_illegal_core',
    'nexa_api',
    'nexa_security',
    'nexa_featureflags',
    'nexa_audit',
    'nexa_logs'
}

shared_scripts {
    '@ox_lib/init.lua',
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
    'server/callbacks.lua',
    'server/events.lua',
    'server/main.lua'
}
