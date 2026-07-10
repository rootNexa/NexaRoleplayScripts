fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_billing'
author 'Nexa Roleplay'
description 'Server-authoritative Nexa billing and invoice foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_characters',
    'nexa_organizations',
    'nexa_economy',
    'nexa_permissions',
    'nexa_playerstate'
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
    'CreateInvoice',
    'GetInvoice',
    'ListInvoices',
    'ListRecipientInvoices',
    'ListIssuerInvoices',
    'PayInvoice',
    'CancelInvoice',
    'DisputeInvoice',
    'CreateInvoiceCredit',
    'GetInvoicePayments',
    'GetOverdueInvoices'
}
