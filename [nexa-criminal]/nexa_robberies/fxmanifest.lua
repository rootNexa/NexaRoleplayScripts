fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_robberies'
author 'Nexa Roleplay'
description 'Server-authoritative Nexa robbery foundations for stores ATMs banks jewellers burglary and vehicle theft'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_crime',
    'nexa_inventory',
    'nexa_items',
    'nexa_economy',
    'nexa_properties',
    'nexa_vehiclekeys'
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
    'GetRobberyLocation',
    'ListRobberyLocations',
    'StartRobbery',
    'GetRobberySession',
    'ResolveRobberyChallenge',
    'ClaimRobberyLoot',
    'TriggerRobberyAlarm',
    'ResetRobberyLocation',
    'getStatus',
    'getSchema'
}
