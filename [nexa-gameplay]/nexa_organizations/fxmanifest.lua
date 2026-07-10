fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_organizations'
author 'Nexa Roleplay'
description 'Server-authoritative Nexa organizations, ranks and memberships foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_identity',
    'nexa_characters',
    'nexa_permissions',
    'nexa_economy',
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
    'GetOrganization',
    'GetOrganizationByName',
    'ListOrganizations',
    'GetOrganizationMembers',
    'GetOrganizationRanks',
    'GetCharacterOrganization',
    'HasOrganizationPermission',
    'InviteMember',
    'AcceptInvitation',
    'RemoveMember',
    'PromoteMember',
    'DemoteMember',
    'CreateOrganization',
    'UpdateOrganization',
    'ActivateOrganization',
    'SuspendOrganization',
    'RegisterStorage',
    'RegisterGarage',
    'EnableModule',
    'DisableModule'
}
