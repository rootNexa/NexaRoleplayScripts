fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_medical'
author 'Nexa Roleplay'
description 'Server-authoritative medical injury hospital EMS treatment and report foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_characters',
    'nexa_playerstate',
    'nexa_permissions',
    'nexa_items',
    'nexa_inventory',
    'nexa_jobs'
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
    'GetMedicalState',
    'ApplyInjury',
    'StabilizePatient',
    'TreatPatient',
    'SetUnconscious',
    'RecordDeath',
    'RespawnAtHospital',
    'CreateMedicalReport',
    'ListMedicalReports',
    'getStatus',
    'getSchema'
}
