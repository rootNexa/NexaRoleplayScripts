fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_vehiclekeys'
author 'Nexa Roleplay'
description 'Server-authoritative vehicle key and access foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_vehicles',
    'nexa_characters',
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
    'HasVehicleKey',
    'ListVehicleKeys',
    'IssueVehicleKey',
    'RevokeVehicleKey',
    'ShareVehicleKey',
    'CanAccessVehicle',
    'SetVehicleLockState',
    'getStatus',
    'getSchema'
}
