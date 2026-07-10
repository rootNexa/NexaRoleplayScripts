fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_theme'
author 'Nexa Roleplay'
description 'Shared GP17 theme tokens for Nexa NUI frontends'
version '0.1.0'

shared_scripts {
    'shared/tokens.lua'
}

client_scripts {
    'client/main.lua'
}

client_exports {
    'getTheme',
    'getPublicTheme'
}
