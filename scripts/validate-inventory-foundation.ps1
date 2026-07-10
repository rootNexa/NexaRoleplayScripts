$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-gameplay]/nexa_inventory'
$requiredFiles = @(
    'fxmanifest.lua',
    'config/shared.lua',
    'shared/constants.lua',
    'server/database.lua',
    'server/main.lua',
    'README.md'
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $resource $file))) {
        throw "Missing inventory file: $file"
    }
}

$all = Get-ChildItem -LiteralPath $resource -Recurse -File | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw
}
$joined = $all -join "`n"

if ($joined -match 'ox_lib|@ox_lib|QBCore|qb-core|qbcore|qbx|qbox|es_extended|ESX|@oxmysql|exports\.oxmysql|MySQL\.') {
    throw 'Forbidden framework or direct oxmysql reference found in nexa_inventory.'
}

foreach ($needle in @(
    '060_inventory_foundation',
    'nexa_inventories',
    'nexa_inventory_items',
    'nexa_inventory_quickslots',
    'nexa_inventory_audit',
    'defaultCharacterSlots = 30',
    'defaultCharacterWeight = 30000',
    'defaultQuickslots = 5'
)) {
    if ($joined -notmatch [regex]::Escape($needle)) {
        throw "Missing inventory foundation marker: $needle"
    }
}

foreach ($export in @('GetInventory','GetCharacterInventory','AddItem','RemoveItem','MoveItem','TransferItem','AssignQuickslot','ClearQuickslot','CreateContainer','CreateDrop')) {
    if ($joined -notmatch "exports\('$export'") {
        throw "Missing inventory export: $export"
    }
}

Write-Host 'validate-inventory-foundation: ok'
