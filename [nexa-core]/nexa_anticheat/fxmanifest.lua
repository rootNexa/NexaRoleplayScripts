fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_anticheat'
author 'Nexa Roleplay'
description 'Phase 12A-K Anticheat-Core, Event, Money, Inventory, Vehicle Protection, Teleport, Noclip, Godmode, Executor/Injection Detection, Evidence Capture und Ban-System ohne Gameplay-Eingriffe'
version '0.12.3'

dependencies {
    'ox_lib',
    'oxmysql',
    'nexa_config',
    'nexa_featureflags',
    'nexa_security',
    'nexa_permissions',
    'nexa_audit',
    'nexa_logs'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'shared/constants.lua'
}

client_scripts {
    'config/client.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/server.lua',
    'server/validators.lua',
    'server/rate_limits.lua',
    'server/tokens.lua',
    'server/event_protection.lua',
    'server/registry.lua',
    'server/integrity.lua',
    'server/session.lua',
    'server/money.lua',
    'server/inventory.lua',
    'server/vehicle.lua',
    'server/teleport.lua',
    'server/noclip.lua',
    'server/godmode.lua',
    'server/executor.lua',
    'server/evidence.lua',
    'server/bans.lua',
    'server/main.lua'
}
