$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_shops') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
if ($text -match 'ox_lib|@ox_lib|qb%-core|qbcore|qbx|es_extended|MySQL\.|oxmysql') { throw 'Forbidden shops dependency marker' }
foreach ($marker in @('nexa_shop_definitions','nexa_shop_items','nexa_shop_transactions','nexa_shop_stock_movements','nexa_shop_deliveries','ShopTypes','GetShop','AddShopItem','GetShopStock')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing shop marker $marker" } }
Write-Host 'validate-shops-foundation: OK'
