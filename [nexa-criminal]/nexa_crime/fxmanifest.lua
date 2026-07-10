fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_crime'
author 'Nexa Roleplay'
description 'Server-authoritative Nexa crime profile reputation heat and session foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_characters',
    'nexa_playerstate',
    'nexa_permissions',
    'nexa_organizations',
    'nexa_jobs',
    'nexa_items',
    'nexa_inventory',
    'nexa_economy',
    'nexa_vehicles',
    'nexa_properties',
    'nexa_jobframework'
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
    'GetCrimeProfile',
    'GetCrimeReputation',
    'GetCrimeHeat',
    'ListCrimeDefinitions',
    'GetCrimeDefinition',
    'CanStartCrime',
    'StartCrime',
    'CancelCrime',
    'GetCrimeSession',
    'ListActiveCrimeSessions',
    'GetCrimeLocation',
    'ListCrimeLocations',
    'GetCrimeCooldown',
    'AdjustCrimeReputation',
    'AdjustCrimeHeat',
    'RegisterCrimeType',
    'RegisterCrimeLocation',
    'RegisterCrimeResponderResolver',
    'RegisterCrimeDispatchAdapter',
    'RegisterCrimeEvidenceProvider',
    'getStatus',
    'getSchema'
}
