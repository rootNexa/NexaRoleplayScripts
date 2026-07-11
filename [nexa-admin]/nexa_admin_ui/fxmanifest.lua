fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_admin_ui'
author 'Nexa Roleplay'
description 'GP18 admin operations surface for Nexa Roleplay'
version '1.0.0'

dependency 'nexa_ui'
dependency 'nexa_api'
dependency 'nexa_beta'

shared_scripts {
    'config/shared.lua'
}

client_scripts {
    'client/main.lua',
    'client/nui.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}
