fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_property_interiors'
author 'Nexa Roleplay'
description 'Server-authoritative property interior instances and routing bucket foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_properties',
    'nexa_playerstate'
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
    'RegisterInteriorDefinition',
    'GetInteriorDefinition',
    'ListInteriorDefinitions',
    'EnterProperty',
    'ConfirmEnterProperty',
    'ExitProperty',
    'GetPropertyInterior',
    'GetPropertyOccupants',
    'ResetPropertyInterior',
    'getStatus',
    'getSchema'
}
