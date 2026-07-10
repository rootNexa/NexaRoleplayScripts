fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-crafting-runtime-tests'
author 'Nexa Roleplay'
description 'Runtime smoke tests for Nexa crafting foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_crafting'
}

server_scripts { 'server/main.lua' }
