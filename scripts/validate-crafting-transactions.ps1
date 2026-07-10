$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_crafting\server\main.lua') -Raw
foreach ($marker in @('Crafting.Begin','Crafting.Complete','Crafting.Cancel','CraftingQuality.Calculate','CraftingTools.Validate','jobAlreadyCompleted')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing crafting transaction marker $marker" } }
Write-Host 'validate-crafting-transactions: OK'
