fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_drugs'
author 'Nexa Roleplay'
description 'Server-authoritative abstract drug grow processing quality and batch foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_crime',
    'nexa_items',
    'nexa_inventory',
    'nexa_crafting',
    'nexa_properties'
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
    'GetDrugDefinition',
    'ListDrugDefinitions',
    'GetDrugBatch',
    'RegisterDrugGrowSite',
    'StartDrugGrow',
    'HarvestDrugGrow',
    'StartDrugProcessing',
    'GetDrugProcessingJob',
    'GetDrugQuality',
    'getStatus',
    'getSchema'
}
