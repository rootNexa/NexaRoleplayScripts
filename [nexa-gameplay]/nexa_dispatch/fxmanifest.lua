fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_dispatch'
author 'Nexa Roleplay'
description 'Server-authoritative dispatch calls units GPS and alert foundation'
version '0.5.0'

dependencies {
    'nexa-core',
    'nexa_characters',
    'nexa_playerstate',
    'nexa_permissions',
    'nexa_jobs',
    'nexa_organizations'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua'
}

server_scripts {
    'server/database.lua',
    'server/main.lua'
}

server_exports {
    'CreateDispatchCall',
    'ListDispatchCalls',
    'AssignDispatchUnit',
    'UpdateDispatchStatus',
    'SetUnitStatus',
    'GetUnitStatus',
    'RegisterDispatchAdapter',
    'getStatus',
    'getSchema'
}
