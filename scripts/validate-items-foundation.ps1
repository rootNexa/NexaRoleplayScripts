$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-gameplay]/nexa_items'
$inventory = Join-Path $root '[nexa-gameplay]/nexa_inventory'

foreach ($file in @('fxmanifest.lua','config/shared.lua','shared/constants.lua','server/database.lua','server/main.lua','README.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $resource $file))) {
        throw "Missing nexa_items file: $file"
    }
}

$itemText = (Get-ChildItem -LiteralPath $resource -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
$inventoryText = (Get-ChildItem -LiteralPath $inventory -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

if ($itemText -match 'ox_lib|@ox_lib|QBCore|qb-core|qbcore|qbx|qbox|es_extended|ESX|@oxmysql|exports\.oxmysql|MySQL\.') {
    throw 'Forbidden framework or direct oxmysql reference found in nexa_items.'
}

foreach ($needle in @(
    '070_item_registry_foundation',
    'nexa_item_definitions',
    'nexa_item_definition_versions',
    'nexa_item_actions',
    'nexa_item_assets',
    'nexa_item_audit',
    'ItemTypes.Register',
    'Items.Register',
    'GetItemDefinition',
    'GetClientCatalog'
)) {
    if ($itemText -notmatch [regex]::Escape($needle)) {
        throw "Missing item registry marker: $needle"
    }
}

if ($inventoryText -match 'internalCatalog|NexaInventoryConfig\.internalCatalog') {
    throw 'Inventory still contains an internal item catalog.'
}

Write-Host 'validate-items-foundation: ok'
