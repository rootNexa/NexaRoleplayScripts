fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-beta-runtime-tests'
author 'Nexa Roleplay'
description 'GP18 runtime validation harness'
version '1.0.0'

dependency 'nexa_beta'

shared_scripts {
    'shared/constants.lua'
}

server_scripts {
    'server/main.lua'
}
