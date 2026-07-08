fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_audit'
author 'Nexa Roleplay'
description 'Audit-Grundlage fuer kritische Nexa-Ereignisse'
version '0.2.0'

dependencies {
    'oxmysql',
    'nexa_config'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua',
    'shared/validators.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    'config/server.lua',
    'server/service.lua',
    'server/main.lua'
}
