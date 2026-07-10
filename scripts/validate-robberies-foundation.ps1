$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-criminal]\nexa_robberies') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('ox_lib','@ox_lib','qbcore','qbx','es_extended','MySQL.','exports.oxmysql','lib.')) { if ($text -match [regex]::Escape($forbidden)) { throw "Forbidden robberies marker $forbidden" } }
foreach ($marker in @('nexa_robbery_locations','nexa_robbery_phases','store_basic','atm_basic','bank_foundation','jeweller_foundation','burglary_foundation','vehicle_theft_foundation','StartRobbery')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing robberies marker $marker" } }
Write-Host 'validate-robberies-foundation: OK'
