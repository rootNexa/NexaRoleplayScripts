fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_admin'
author 'Nexa Roleplay'
description 'Server-authoritative admin foundation for Nexa Roleplay'
version '1.0.0'

dependencies {
    'nexa-core',
    'nexa_identity',
    'nexa_characters',
    'nexa_permissions',
    'nexa_api'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    'config/server.lua',
    'server/validators.lua',
    'server/main.lua',
    'server/callbacks.lua'
}

server_exports {
    'WarnPlayer',
    'KickPlayer',
    'BanPlayer',
    'UnbanPlayer',
    'GoToPlayer',
    'BringPlayer',
    'ReturnPlayer',
    'SetPlayerFrozen',
    'HealPlayer',
    'RevivePlayer',
    'StartSpectate',
    'StopSpectate',
    'StartNoclip',
    'StopNoclip',
    'CreateAdminNote',
    'ListAdminNotes',
    'GetAdminActionState',
    'ResolveConnection',
    'IsAccountBanned',
    'ListActions'
}
