fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_items'
author 'Nexa Roleplay'
description 'Server-authoritative item registry and Item Studio foundation'
version '0.2.0'

dependencies {
    'nexa-core',
    'nexa_permissions',
    'nexa_api',
    'nexa_ui'
}

shared_scripts {
    'config/shared.lua',
    'shared/constants.lua'
}

server_scripts {
    'server/database.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

server_exports {
    'CreateItem',
    'GetItem',
    'ListItems',
    'UpdateItem',
    'SetItemEnabled',
    'DeleteItem',
    'PublishItem',
    'DeprecateItem',
    'GetItemDefinition',
    'ItemExists',
    'GetItemWeight',
    'GetMaxStack',
    'IsStackable',
    'ValidateMetadata',
    'CanUse',
    'CanQuickslot',
    'CanDrop',
    'CanTrade',
    'IsContainer',
    'GetClientDefinition',
    'GetClientCatalog',
    'RegisterItemType',
    'RegisterActionHandler'
}
