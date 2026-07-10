fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_shops'
author 'Nexa Roleplay'
description 'Server-authoritative Nexa shops commerce foundation'
version '0.2.0'

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
    'GetShop',
    'ListShops',
    'GetShopCatalog',
    'GetShopItem',
    'GetShopStock',
    'CanAccessShop',
    'BuyFromShop',
    'SellToShop',
    'AdjustShopStock',
    'CreateShop',
    'UpdateShop',
    'AddShopItem',
    'UpdateShopItem',
    'RemoveShopItem',
    'CreateShopDelivery',
    'AssignShopDelivery',
    'CompleteShopDelivery',
    'getStatus',
    'getSchema'
}
