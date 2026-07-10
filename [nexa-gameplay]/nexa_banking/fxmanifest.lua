fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_banking'
author 'Nexa Roleplay'
description 'Banking, private Konten, Transaktionen und Rechnungen fuer Phase 4C'
version '0.4.2'

dependencies {
    'nexa_ui',
    'nexa_api',
    'nexa_audit',
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
    'server/validators.lua',
    'server/callbacks.lua',
    'server/events.lua',
    'server/main.lua'
}
