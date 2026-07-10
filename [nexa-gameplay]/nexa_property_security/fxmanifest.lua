fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_property_security'
author 'Nexa Roleplay'
description 'Server-authoritative property alarm and burglary foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_properties',
    'nexa_propertykeys',
    'nexa_inventory'
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
    'GetPropertySecurity',
    'ArmProperty',
    'DisarmProperty',
    'TriggerPropertyAlarm',
    'ResetPropertyAlarm',
    'BeginPropertyBurglary',
    'ResolvePropertyBurglary',
    'GetActivePropertyBurglary',
    'EndPropertyBurglary',
    'getStatus',
    'getSchema'
}
