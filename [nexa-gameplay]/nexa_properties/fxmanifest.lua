fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_properties'
author 'Nexa Roleplay'
description 'Server-authoritative property definitions, ownership, leases and property foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_characters',
    'nexa_permissions',
    'nexa_playerstate',
    'nexa_economy',
    'nexa_inventory',
    'nexa_garages'
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
    'GetProperty',
    'GetPropertyByNumber',
    'ListProperties',
    'GetCharacterProperties',
    'GetOwnedProperties',
    'GetRentedProperties',
    'CreateProperty',
    'UpdateProperty',
    'BuyProperty',
    'SellProperty',
    'TransferProperty',
    'GetPropertyQuote',
    'GetLease',
    'GetCharacterLease',
    'CreateLease',
    'TerminateLease',
    'PayRent',
    'GetRentStatus',
    'ProcessDueRent',
    'MarkRentOverdue',
    'ListResidents',
    'InviteResident',
    'AcceptResidentInvitation',
    'RemoveResident',
    'UpdateResidentPermissions',
    'GetPropertyStorage',
    'OpenPropertyStorage',
    'GetPropertyWardrobes',
    'CanUsePropertyWardrobe',
    'GetPropertyGarage',
    'ListPropertyVehicles',
    'RegisterFurnitureDefinition',
    'PlaceFurniture',
    'MoveFurniture',
    'RemoveFurniture',
    'ListFurniture',
    'AdminSetPropertyStatus',
    'CreatorCreateDefinition',
    'CreatorPublishDefinition',
    'CreatorDisableDefinition',
    'CreatorArchiveDefinition',
    'getStatus',
    'getSchema'
}
