fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_garages'
author 'Nexa Roleplay'
description 'Server-authoritative vehicle garage storage and retrieval foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_vehicles',
    'nexa_vehiclekeys',
    'nexa_organizations',
    'nexa_permissions'
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
    'RegisterGarage',
    'GetGarage',
    'ListGarages',
    'GetStoredVehicles',
    'StoreVehicle',
    'RetrieveVehicle',
    'CanUseGarage',
    'getStatus',
    'getSchema'
}
