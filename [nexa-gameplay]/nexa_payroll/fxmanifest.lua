fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa_payroll'
author 'Nexa Roleplay'
description 'Server-authoritative Nexa payroll foundation'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_characters',
    'nexa_jobs',
    'nexa_organizations',
    'nexa_economy',
    'nexa_permissions'
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
    'GetPayrollPolicy',
    'ListPayrollPolicies',
    'CreatePayrollPolicy',
    'UpdatePayrollPolicy',
    'GetPayrollPeriod',
    'GetPayrollRun',
    'ListPayrollRuns',
    'CalculatePayroll',
    'ExecutePayroll',
    'RetryPayroll',
    'CancelPayroll',
    'GetPayrollEntry',
    'ListPayrollEntries',
    'GetDutyTimeReport'
}
