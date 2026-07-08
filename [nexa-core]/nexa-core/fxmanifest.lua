fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-core'
author 'Nexa Roleplay'
description 'Eigenes Framework-Fundament fuer Nexa Roleplay'
version '0.1.0'

dependencies {
    'ox_lib',
    'oxmysql'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/constants.lua',
    'shared/config.lua',
    'shared/init.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/permissions.lua',
    'server/players.lua',
    'server/characters.lua',
    'server/callbacks.lua',
    'server/events.lua',
    'server/exports.lua',
    'server/bootstrap.lua',
    'server/main.lua'
}

client_scripts {
    'client/callbacks.lua',
    'client/events.lua',
    'client/main.lua'
}

server_exports {
    'GetCoreObject',
    'GetPlayer',
    'GetCharacter',
    'HasPermission',
    'GetIdentifier',
    'CreateCharacter',
    'SelectCharacter'
}
