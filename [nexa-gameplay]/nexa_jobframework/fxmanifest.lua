fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_jobframework'
author 'Nexa Roleplay'
description 'Server-authoritative Nexa legal job framework foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_characters',
    'nexa_playerstate',
    'nexa_permissions',
    'nexa_items',
    'nexa_inventory',
    'nexa_economy',
    'nexa_organizations',
    'nexa_jobs',
    'nexa_vehicles',
    'nexa_garages',
    'nexa_properties',
    'nexa_crafting'
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
    'GetJobDefinition',
    'ListJobDefinitions',
    'CanStartJob',
    'StartJob',
    'CancelJob',
    'GetJobSession',
    'GetCharacterJobSession',
    'ListActiveJobSessions',
    'GetTaskProgress',
    'CompleteJobTask',
    'GetJobRewards',
    'RetryJobReward',
    'CreateJobDefinition',
    'UpdateJobDefinition',
    'ActivateJobDefinition',
    'SuspendJobDefinition',
    'DisableJobDefinition',
    'RegisterJobType',
    'RegisterTaskType',
    'RegisterResourceNode',
    'RegisterProductionChain',
    'getStatus',
    'getSchema'
}
