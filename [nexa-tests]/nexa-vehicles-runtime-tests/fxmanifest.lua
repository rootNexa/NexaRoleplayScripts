fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-vehicles-runtime-tests'
author 'Nexa Roleplay'
description 'Runtime smoke tests for Nexa vehicle foundations'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_vehicles',
    'nexa_vehiclekeys',
    'nexa_garages',
    'nexa_impound'
}

server_scripts {
    'server/main.lua'
}
