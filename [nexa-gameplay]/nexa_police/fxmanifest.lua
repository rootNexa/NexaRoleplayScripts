fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_police'
author 'Nexa Roleplay'
description 'Server-authoritative police agency arrest restraint search seizure and control foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_characters',
    'nexa_playerstate',
    'nexa_permissions',
    'nexa_jobs',
    'nexa_organizations',
    'nexa_inventory',
    'nexa_vehicles',
    'nexa_vehiclekeys',
    'nexa_evidence',
    'nexa_dispatch'
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
    'RegisterPoliceAgency',
    'GetPoliceAgency',
    'ListPoliceAgencies',
    'CreateArrest',
    'SetHandcuffed',
    'SetEscorted',
    'SearchPerson',
    'SeizeItem',
    'CheckWeapon',
    'CheckVehicle',
    'CheckPerson',
    'getStatus',
    'getSchema'
}
