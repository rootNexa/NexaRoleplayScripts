fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_mdt'
author 'Nexa Roleplay'
description 'MDT Anzeige- und Workflow-System ohne Gameplay-Entscheidungen'
version '0.5.4'

dependencies {
    'nexa_ui',
    'nexa_api',
    'nexa_security',
    'nexa_permissions',
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
    'server/state.lua',
    'server/callbacks.lua',
    'server/main.lua'
}
