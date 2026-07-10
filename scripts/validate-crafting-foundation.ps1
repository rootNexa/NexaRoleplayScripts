$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_crafting') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
if ($text -match 'ox_lib|@ox_lib|qb%-core|qbcore|qbx|es_extended|MySQL\.|oxmysql') { throw 'Forbidden crafting dependency marker' }
foreach ($marker in @('nexa_crafting_recipes','nexa_crafting_recipe_inputs','nexa_crafting_recipe_outputs','nexa_crafting_stations','nexa_crafting_jobs','CraftingTypes','CreateRecipe','RegisterCraftingStation')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing crafting marker $marker" } }
Write-Host 'validate-crafting-foundation: OK'
