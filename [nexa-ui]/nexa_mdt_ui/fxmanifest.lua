fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_mdt_ui'
author 'Nexa Roleplay'
description 'GP17 MDT NUI frontend using nexa_mdt GP16 APIs'
version '0.1.0'

dependencies { 'nexa_ui', 'nexa_api', 'nexa_theme', 'nexa_ui_components', 'nexa_mdt' }

ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/app.js' }
client_scripts { 'client/main.lua', 'client/nui.lua' }
client_exports { 'open', 'close', 'refresh' }
