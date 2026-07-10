$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_shops\server\main.lua') -Raw
foreach ($marker in @('ShopTransactions.Buy','ShopTransactions.Sell','Stock.Reserve','Stock.Commit','GetShopTransaction','CompensateShopTransaction')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing shop transaction marker $marker" } }
Write-Host 'validate-shop-transactions: OK'
