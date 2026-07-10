$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-criminal]\nexa_crime') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('ox_lib','@ox_lib','qbcore','qbx','es_extended','MySQL.','exports.oxmysql','lib.')) { if ($text -match [regex]::Escape($forbidden)) { throw "Forbidden crime marker $forbidden" } }
foreach ($marker in @('nexa_crime_profiles','nexa_crime_definitions','nexa_crime_sessions','nexa_crime_reputation_history','nexa_crime_heat_history','CrimeTypes','GetCrimeProfile','StartCrime','RegisterCrimeResponderResolver')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing crime marker $marker" } }
Write-Host 'validate-crime-foundation: OK'
