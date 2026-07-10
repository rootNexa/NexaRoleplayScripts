$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-criminal]\nexa_robberies') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($marker in @('nexa_robbery_loot_points','nexa_robbery_loot_claims','ClaimRobberyLoot','idempotency_key','stolen_item_metadata','lootAlreadyClaimed')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing robbery loot marker $marker" } }
Write-Host 'validate-robberies-loot: OK'
