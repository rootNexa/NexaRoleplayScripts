fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-jobframework-runtime-tests'
author 'Nexa Roleplay'
description 'Development-only runtime smoke tests for Nexa jobframework and legaljobs'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_jobframework',
    'nexa_legaljobs'
}

server_scripts { 'server/main.lua' }
