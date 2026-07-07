fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_security'
author 'Nexa Roleplay'
description 'Eventschutz und Missbrauchserkennung fuer Nexa Roleplay'
version '0.2.0'

dependencies {
    'ox_lib',
    'nexa_config',
    'nexa_logs',
    'nexa_audit'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'shared/constants.lua',
    'shared/validators.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    'config/server.lua',
    'server/rate_limits.lua',
    'server/main.lua'
}
