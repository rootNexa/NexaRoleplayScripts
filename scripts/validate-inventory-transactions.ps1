$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$server = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_inventory/server/main.lua') -Raw

foreach ($needle in @(
    'Inventory.locks',
    'acquireLocks',
    'releaseLocks',
    'withLocks',
    'table.sort(ids)',
    'TransferItem',
    'Weight.CanAdd',
    'Slots.FindFree',
    'Slots.FindStack',
    'CleanupQuickslotsForItem',
    'CheckInventory',
    'RecalculateWeight',
    'containerNestingForbidden',
    'defaultDropTtlSeconds'
)) {
    if ($server -notmatch [regex]::Escape($needle)) {
        throw "Missing transaction/integrity marker: $needle"
    }
}

if ($server -match 'Wait\(0\)|while true do') {
    throw 'Inventory contains an uncontrolled loop.'
}

Write-Host 'validate-inventory-transactions: ok'
