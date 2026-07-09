fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_hud'
author 'Nexa Roleplay'
description 'Read-only HUD fuer Status, Job, Firma, Konto, Voice und Fahrzeuganzeige'
version '0.5.1'

dependencies {
    'nexa_ui',
    'nexa_api'
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
    'server/callbacks.lua',
    'server/main.lua'
}
