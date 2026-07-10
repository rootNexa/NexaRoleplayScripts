fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-character'
author 'Nexa Roleplay'
description 'Character foundation layer for Nexa Framework'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_characters'
}

shared_scripts {
    'shared/constants.lua',
    'shared/config.lua'
}

server_scripts {
    'server/validation.lua',
    'server/main.lua',
    'server/exports.lua'
}

client_script 'client/main.lua'

server_exports {
    'ListCharacters',
    'CreateCharacter',
    'SelectCharacter',
    'GetActiveCharacter',
    'UpdateCharacter'
}
