fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_characters'
author 'Nexa Roleplay'
description 'Character domain model for Nexa Framework'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_identity'
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
    'ListCharacters',
    'GetCharacter',
    'GetActiveCharacter',
    'CreateCharacter',
    'SelectCharacter',
    'UpdateCharacter',
    'DeleteCharacter',
    'BlockCharacter',
    'RestoreCharacter'
}
