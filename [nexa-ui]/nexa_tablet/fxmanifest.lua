fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_tablet'
author 'Nexa Roleplay'
description 'Tablet UI-Shell und App-Container ohne Fachlogik'
version '0.5.2'

dependencies {
    'ox_lib',
    'nexa_ui',
    'nexa_api',
    'nexa_permissions'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

shared_scripts {
    '@ox_lib/init.lua',
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
