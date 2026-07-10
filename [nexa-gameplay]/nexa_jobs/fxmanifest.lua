fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_jobs'
author 'Nexa Roleplay'
description 'Server-authoritative Nexa job lifecycle and duty foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_characters',
    'nexa_playerstate',
    'nexa_organizations',
    'nexa_permissions'
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
    'GetJob',
    'GetJobByCharacter',
    'IsOnDuty',
    'StartDuty',
    'StopDuty',
    'GetActiveDutyMembers',
    'ForceStopDuty'
}
