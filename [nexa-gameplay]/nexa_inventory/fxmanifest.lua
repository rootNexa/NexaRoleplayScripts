fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_inventory'
author 'Nexa Roleplay'
description 'Server-authoritative Nexa inventory foundation'
version '0.2.0'

dependencies {
    'nexa-core',
    'nexa_identity',
    'nexa_characters',
    'nexa_playerstate',
    'nexa_permissions',
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
    'GetInventory',
    'GetCharacterInventory',
    'GetItem',
    'GetItems',
    'HasItem',
    'CanCarry',
    'AddItem',
    'RemoveItem',
    'MoveItem',
    'TransferItem',
    'GetWeight',
    'GetLimits',
    'AssignQuickslot',
    'ClearQuickslot',
    'CreateContainer',
    'CreateDrop',
    'CreateInventory',
    'ListInventoryItems',
    'SetItemAmount',
    'ClearInventory',
    'CheckInventory',
    'RecalculateWeight'
}
