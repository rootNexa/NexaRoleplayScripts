fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_evidence'
author 'Nexa Roleplay'
description 'Server-authoritative forensic evidence hooks traces and locker foundation'
version '1.0.0'

dependencies {
    'nexa-core',
    'nexa_items',
    'nexa_inventory',
    'nexa_crime'
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
    'CollectEvidence',
    'ListEvidence',
    'UpdateEvidenceStatus',
    'RegisterEvidenceHook',
    'CreateTrace',
    'StoreEvidenceLocker',
    'getStatus',
    'getSchema'
}
