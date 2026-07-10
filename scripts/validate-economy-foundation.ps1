$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-gameplay]/nexa_economy'

foreach ($file in @('fxmanifest.lua','config/shared.lua','shared/constants.lua','server/database.lua','server/main.lua','README.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $resource $file))) {
        throw "Missing nexa_economy file: $file"
    }
}

$text = (Get-ChildItem -LiteralPath $resource -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

if ($text -match 'ox_lib|@ox_lib|QBCore|qb-core|qbcore|qbx|qbox|es_extended|ESX|@oxmysql|exports\.oxmysql|MySQL\.|lib\.') {
    throw 'Forbidden framework, direct oxmysql or lib reference found in nexa_economy.'
}

foreach ($needle in @(
    '080_economy_foundation',
    'nexa_economy_accounts',
    'nexa_economy_transactions',
    'nexa_economy_ledger',
    'nexa_economy_reservations',
    'nexa_economy_audit',
    'nexa_economy_sagas',
    'currency_cash',
    'currency_dirty_cash',
    "exports('GetAccount'",
    "exports('GetCharacterBankAccount'",
    "exports('Credit'",
    "exports('Debit'",
    "exports('Transfer'"
)) {
    if ($text -notmatch [regex]::Escape($needle)) {
        throw "Missing economy foundation marker: $needle"
    }
}

Write-Host 'validate-economy-foundation: ok'
