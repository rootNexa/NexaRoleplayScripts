fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-crime-runtime-tests'
author 'Nexa Roleplay'
description 'Development-only runtime smoke tests for Nexa crime foundations'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_crime',
    'nexa_robberies',
    'nexa_drugs',
    'nexa_blackmarket'
}

server_scripts { 'server/main.lua' }
