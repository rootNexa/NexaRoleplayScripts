fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_phone'
author 'Nexa Roleplay'
description 'Phone UI-Shell mit sicheren Basisfunktionen ohne Voice-System'
version '0.5.3'

dependencies {
    'nexa_ui',
    'nexa_api',
    'nexa_security',
    'nexa_audit',
    'nexa_logs'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'locales/de.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua',
    'client/nui.lua'
}

server_scripts {
    'config/server.lua',
    'server/database.lua',
    'server/state.lua',
    'server/callbacks.lua',
    'server/main.lua'
}
