fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-organizations-runtime-tests'
author 'Nexa Roleplay'
description 'Development-only runtime harness for nexa_organizations and nexa_jobs'
version '1.0.0'

dependencies {
    'nexa_organizations',
    'nexa_jobs'
}

server_script 'server/main.lua'
