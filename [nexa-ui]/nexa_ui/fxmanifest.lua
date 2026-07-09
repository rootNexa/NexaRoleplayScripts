fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_ui'
author 'Nexa Roleplay'
description 'Zentrales NEXA Design-System, NUI-Grundstruktur und UI-Hilfen'
version '0.5.0'

dependencies {
    'nexa_config',
    'nexa_locales'
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
    'shared/types.lua',
    'shared/utils.lua',
    'locales/de.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua',
    'client/nui.lua'
}

client_exports {
    'open',
    'close',
    'notify',
    'confirm',
    'menu',
    'getTheme',
    'getLocale',
    'registerContext',
    'showContext',
    'hideContext',
    'getOpenContextMenu'
}

server_scripts {
    'config/server.lua',
    'server/main.lua'
}
