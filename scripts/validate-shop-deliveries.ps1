$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_shops\server\main.lua') -Raw
foreach ($marker in @('Deliveries.Create','Deliveries.Assign','Deliveries.Pickup','Deliveries.Deliver','CancelShopDelivery','deliveryCompleted')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing shop delivery marker $marker" } }
Write-Host 'validate-shop-deliveries: OK'
