$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$db = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_economy/server/database.lua') -Raw
$main = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_economy/server/main.lua') -Raw

foreach ($needle in @(
    'nexa_economy_ledger',
    'balance_before',
    'balance_after',
    'reserved_before',
    'reserved_after',
    'InsertLedger',
    'GetLedger',
    'transaction_id',
    'correlation_id'
)) {
    if (($db + $main) -notmatch [regex]::Escape($needle)) {
        throw "Missing economy ledger marker: $needle"
    }
}

if ($main -match 'UPDATE nexa_economy_accounts SET balance' -and $main -notmatch 'INSERT INTO nexa_economy_ledger') {
    throw 'Balance updates exist without visible ledger insert path.'
}

Write-Host 'validate-economy-ledger: ok'
