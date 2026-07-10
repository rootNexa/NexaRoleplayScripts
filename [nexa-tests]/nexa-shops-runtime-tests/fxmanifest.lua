fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-shops-runtime-tests'
author 'Nexa Roleplay'
description 'Runtime smoke tests for Nexa shops foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_shops'
}

server_scripts { 'server/main.lua' }
