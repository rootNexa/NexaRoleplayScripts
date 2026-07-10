fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_economy'
author 'Nexa Roleplay'
description 'Server-authoritative Nexa economy accounts, ledger and cash integration'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_api',
    'nexa_characters',
    'nexa_playerstate',
    'nexa_items',
    'nexa_inventory'
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
    'GetAccount',
    'GetCharacterBankAccount',
    'GetBalance',
    'GetAvailableBalance',
    'GetReservedBalance',
    'GetLedger',
    'GetTransaction',
    'GetCash',
    'GetDirtyCash',
    'CanAfford',
    'Credit',
    'Debit',
    'Transfer',
    'Reserve',
    'CaptureReservation',
    'ReleaseReservation',
    'DepositCash',
    'WithdrawCash',
    'AddCash',
    'RemoveCash',
    'AddDirtyCash',
    'RemoveDirtyCash'
}
