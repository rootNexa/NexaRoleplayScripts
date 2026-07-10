fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_ems'
author 'Nexa Roleplay'
description 'EMS workflow foundation for medical inspection, treatment, transport and hospital records'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_api',
    'nexa_medical'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua'
}

server_scripts {
    'server/database.lua',
    'server/main.lua'
}
