$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-criminal]\nexa_blackmarket') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('ox_lib','@ox_lib','qbcore','qbx','es_extended','MySQL.','exports.oxmysql','lib.')) { if ($text -match [regex]::Escape($forbidden)) { throw "Forbidden blackmarket marker $forbidden" } }
foreach ($marker in @('nexa_blackmarket_markets','nexa_blackmarket_catalog','nexa_blackmarket_fences','GetAccessibleBlackMarkets','BuyFromBlackMarket','SellToFence','GetFenceOffer')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing blackmarket marker $marker" } }
Write-Host 'validate-blackmarket-foundation: OK'
