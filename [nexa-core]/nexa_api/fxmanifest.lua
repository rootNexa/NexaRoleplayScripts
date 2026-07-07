fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_api'
author 'Nexa Roleplay'
description 'Zentrale API-Infrastruktur und Contracts fuer Nexa Roleplay'
version '0.2.0'

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory',
    'qbx_core',
    'nexa_config',
    'nexa_security',
    'nexa_anticheat',
    'nexa_audit',
    'nexa_permissions',
    'nexa_logs'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'shared/constants.lua',
    'shared/errors.lua',
    'shared/types.lua',
    'shared/contracts.lua',
    'shared/anticheat_contracts.lua',
    'shared/response.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua',
    'client/notification.lua',
    'client/bridge_qbox.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/server.lua',
    'server/registry.lua',
    'server/main.lua',
    'server/audit.lua',
    'server/security.lua',
    'server/anticheat.lua',
    'server/permission.lua',
    'server/character.lua',
    'server/inventory.lua',
    'server/account.lua',
    'server/property.lua',
    'server/job.lua',
    'server/business.lua',
    'server/faction.lua',
    'server/ems.lua',
    'server/police.lua',
    'server/criminal.lua',
    'server/vehicle.lua',
    'server/dispatch.lua',
    'server/document.lua',
    'server/license.lua',
    'server/world.lua',
    'server/notification.lua',
    'server/bridge_qbox.lua'
}
