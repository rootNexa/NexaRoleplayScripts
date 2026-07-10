$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-gameplay]/nexa_inventory'
$server = Get-Content -LiteralPath (Join-Path $resource 'server/main.lua') -Raw
$all = Get-ChildItem -LiteralPath $resource -Recurse -File | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw
}
$joined = $all -join "`n"

if ($joined -match 'ox_lib|@ox_lib|QBCore|qb-core|qbcore|qbx|qbox|es_extended|ESX|@oxmysql|exports\.oxmysql|MySQL\.') {
    throw 'Forbidden dependency or direct DB access found.'
}

foreach ($needle in @('validateMetadata', 'metadataDepth', 'normalizeAmount', 'itemDefinition', 'nexa_items:GetItem', 'audit(')) {
    if ($server -notmatch [regex]::Escape($needle)) {
        throw "Missing security marker: $needle"
    }
}

$callbackMatches = [regex]::Matches($server, 'RegisterServerCallback\([\s\S]*?\n\s*end\)')
foreach ($match in $callbackMatches) {
    if ($match.Value -match 'payload\.source|payload\.character_id') {
        throw 'Inventory server appears to trust client-provided source or character_id in callback payload.'
    }
}

if ($server -match 'TriggerServerEvent') {
    throw 'Server inventory code must not trigger client-origin server events.'
}

if ($server -notmatch 'source = source') {
    throw 'Callback context must bind to the actual FiveM source.'
}

Write-Host 'validate-inventory-security: ok'
