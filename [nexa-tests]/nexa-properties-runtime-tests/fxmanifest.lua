fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-properties-runtime-tests'
author 'Nexa Roleplay'
description 'Runtime smoke tests for Nexa property foundations'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_properties',
    'nexa_propertykeys',
    'nexa_property_interiors',
    'nexa_property_security'
}

server_scripts {
    'server/main.lua'
}
