fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_blackmarket'
author 'Nexa Roleplay'
description 'Server-authoritative blackmarket fences dirty cash and laundering foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_crime',
    'nexa_shops',
    'nexa_items',
    'nexa_inventory',
    'nexa_economy'
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
    'GetAccessibleBlackMarkets',
    'GetBlackMarketCatalog',
    'BuyFromBlackMarket',
    'SellToFence',
    'GetFenceOffer',
    'BeginMoneyLaundering',
    'GetMoneyLaunderingJob',
    'getStatus',
    'getSchema'
}
