fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_api'
author 'Nexa Roleplay'
description 'Zentrale API-, Contract-, Callback- und Registry-Schicht fuer Nexa'
version '1.0.0'

dependencies {
    'nexa-lib',
    'nexa-core'
}

shared_scripts {
    'shared/constants.lua',
    'shared/config.lua',
    'shared/validation.lua',
    'shared/contracts.lua'
}

server_scripts {
    'server/registry.lua',
    'server/contracts.lua',
    'server/callbacks.lua',
    'server/exports.lua',
    'server/main.lua'
}

client_scripts {
    'client/callbacks.lua',
    'client/exports.lua',
    'client/main.lua'
}

server_exports {
    'GetApi',
    'RegisterModule',
    'GetModule',
    'ListModules',
    'IsModuleReady',
    'SetModuleReady',
    'RegisterContract',
    'GetContract',
    'ListContracts',
    'ValidateContractPayload',
    'RegisterServerCallback',
    'TriggerServerCallback',
    'RegisterClientCallback',
    'HasPermission',
    'RequirePermission',
    'GetPlayer',
    'GetCharacter',
    'GetIdentifier'
}

client_exports {
    'GetApi',
    'RegisterClientCallback',
    'TriggerServerCallback'
}
