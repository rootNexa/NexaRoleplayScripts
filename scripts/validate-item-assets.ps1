$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$server = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_items/server/main.lua') -Raw
$db = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_items/server/database.lua') -Raw

foreach ($needle in @('Assets.ValidateReference','https://','localhost','127.0.0.1','192%.168%.','file://','javascript:','data:','nexa_item_assets')) {
    if (($server + $db) -notmatch [regex]::Escape($needle)) {
        throw "Missing item asset marker: $needle"
    }
}

Write-Host 'validate-item-assets: ok'
