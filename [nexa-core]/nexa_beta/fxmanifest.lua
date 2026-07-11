fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_beta'
author 'Nexa Roleplay'
description 'GP18 beta readiness, integration health, creator registry and release metadata'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_api'
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
    'RegisterCreator',
    'ListCreators',
    'SetFeatureFlag',
    'GetReadiness',
    'CollectHealth',
    'RecordPerformanceSnapshot',
    'GetReleaseMetadata',
    'getSchema',
    'getStatus'
}
