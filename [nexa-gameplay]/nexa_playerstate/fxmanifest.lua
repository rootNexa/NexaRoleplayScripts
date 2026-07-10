fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_playerstate'
author 'Nexa Roleplay'
description 'Server-authoritative player gameplay lifecycle and spawn pipeline'
version '1.0.0'

dependencies {
    'nexa-core',
    'nexa_identity',
    'nexa_characters'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/validators.lua',
    'server/main.lua'
}

server_exports {
    'GetPlayerState',
    'IsPlayerActive',
    'IsPlayerReadyForGameplay',
    'GetActiveCharacter',
    'GetLastPosition',
    'RequestSpawn',
    'RegisterSpawnProvider',
    'GetByAccount',
    'GetByCharacter',
    'GetTransitionHistory',
    'SetLifeState',
    'GetLifeState',
    'SetBucket',
    'GetBucket',
    'AllowPositionJump'
}
