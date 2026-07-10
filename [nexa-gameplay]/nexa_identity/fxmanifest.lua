fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_identity'
author 'Nexa Roleplay'
description 'Account and connection identity domain for Nexa Framework'
version '0.5.0'

dependencies {
    'nexa-core'
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
    'GetAccount',
    'GetAccountId',
    'GetAccountStatus',
    'IsAccountReady'
}
