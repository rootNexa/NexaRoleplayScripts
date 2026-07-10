fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_legaljobs'
author 'Nexa Roleplay'
description 'Nexa legal jobs foundation definitions for the reusable job framework'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_jobframework',
    'nexa_items',
    'nexa_inventory',
    'nexa_economy',
    'nexa_vehicles',
    'nexa_garages',
    'nexa_crafting'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua'
}

server_scripts {
    'server/main.lua'
}

server_exports {
    'RegisterLegalJobDefinitions',
    'GetLegalJobDefinitions',
    'GetLegalJobDefinition',
    'getStatus'
}
