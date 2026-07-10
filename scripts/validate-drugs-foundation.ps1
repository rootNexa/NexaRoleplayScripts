$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-criminal]\nexa_drugs') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('ox_lib','@ox_lib','qbcore','qbx','es_extended','MySQL.','exports.oxmysql','lib.')) { if ($text -match [regex]::Escape($forbidden)) { throw "Forbidden drugs marker $forbidden" } }
foreach ($marker in @('nexa_drug_definitions','nexa_drug_grow_sites','nexa_drug_batches','nexa_drug_processing_jobs','DrugTypes','StartDrugGrow','HarvestDrugGrow','GetDrugQuality')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing drugs marker $marker" } }
Write-Host 'validate-drugs-foundation: OK'
