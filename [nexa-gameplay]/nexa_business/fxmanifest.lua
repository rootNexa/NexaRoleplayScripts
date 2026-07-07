fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_business'
author 'Nexa Roleplay'
description 'Business Core, Mitglieder, Konten und Transaktionen fuer Phase 4D'
version '0.4.3'

dependencies {
    'ox_lib',
    'nexa_jobs_core',
    'nexa_api',
    'nexa_audit',
    'nexa_security',
    'nexa_permissions',
    'nexa_logs'
}

shared_scripts {
    '@ox_lib/init.lua',
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
