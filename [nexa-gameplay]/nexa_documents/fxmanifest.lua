fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_documents'
author 'Nexa Roleplay'
description 'Dokumentenverwaltung fuer Phase 4B'
version '0.4.1'

dependencies {
    'nexa_ui',
    'nexa_api',
    'nexa_identity',
    'nexa_security',
    'nexa_logs'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    'config/server.lua',
    'server/database.lua',
    'server/validators.lua',
    'server/callbacks.lua',
    'server/events.lua',
    'server/main.lua'
}
