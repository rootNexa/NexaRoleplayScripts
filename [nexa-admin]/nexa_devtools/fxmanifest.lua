fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_devtools'
author 'Nexa Roleplay'
description 'Development-only Diagnosewerkzeuge mit harter Production-Sperre'
version '0.11.0'

dependencies {
    'nexa_config',
    'nexa_logs',
    'nexa_audit',
    'nexa_api'
}

shared_scripts {
    'shared/constants.lua'
}

server_scripts {
    'config/server.lua',
    'server/main.lua'
}
