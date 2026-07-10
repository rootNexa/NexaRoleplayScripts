fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_licenses'
author 'Nexa Roleplay'
description 'Server-authoritative driving weapon hunting and business license foundation'
version '0.5.0'

dependencies {
    'nexa-core',
    'nexa_characters',
    'nexa_permissions',
    'nexa_documents'
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
    'RegisterLicenseType',
    'ListLicenseTypes',
    'IssueLicense',
    'RevokeLicense',
    'ValidateLicense',
    'GetLicenseHistory',
    'getStatus',
    'getSchema'
}
