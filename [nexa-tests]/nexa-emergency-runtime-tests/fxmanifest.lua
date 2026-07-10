fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nexa-emergency-runtime-tests'
author 'Nexa Roleplay'
description 'Development-only runtime smoke tests for medical EMS police dispatch MDT evidence and licenses'
version '0.1.0'

dependencies {
    'nexa-core',
    'nexa_medical',
    'nexa_ems',
    'nexa_police',
    'nexa_dispatch',
    'nexa_evidence',
    'nexa_licenses'
}

server_scripts { 'server/main.lua' }
