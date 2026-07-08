fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-identity'
author 'Nexa Roleplay'
description 'Minimal character flow for Nexa Framework'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa-character'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

shared_script 'shared/config.lua'

server_script 'server/main.lua'

client_script 'client/main.lua'
