$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-gameplay]/nexa_items'
$text = (Get-ChildItem -LiteralPath $resource -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
$server = Get-Content -LiteralPath (Join-Path $resource 'server/main.lua') -Raw

if ($text -match 'ox_lib|@ox_lib|QBCore|qb-core|qbcore|qbx|qbox|es_extended|ESX|@oxmysql|exports\.oxmysql|MySQL\.') {
    throw 'Forbidden dependency or direct DB access found.'
}

if ($text -cmatch '\bloadstring\s*\(|\bdofile\s*\(|\bload\s*\(') {
    throw 'Dynamic Lua execution marker found.'
}

foreach ($needle in @('normalizeName', 'Metadata.FilterForClient', 'serverOnly', 'sensitive', 'Assets.ValidateReference', 'assetSsrfRejected')) {
    if ($server -notmatch [regex]::Escape($needle)) {
        throw "Missing item security marker: $needle"
    }
}

if ($server -match 'TriggerEvent\(.*handler|TriggerClientEvent\(.*handler') {
    throw 'Item handlers must not be free event names.'
}

Write-Host 'validate-items-security: ok'
