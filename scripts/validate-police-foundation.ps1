$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_police') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('ox_lib','@ox_lib','qbcore','qbx','es_extended','MySQL.','exports.oxmysql','lib.')) { if ($text -match [regex]::Escape($forbidden)) { throw "Forbidden police marker $forbidden" } }
foreach ($marker in @('nexa_police_agencies','CreateArrest','SetHandcuffed','SetEscorted','SearchPerson','SeizeItem','CheckWeapon','CheckVehicle')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing police marker $marker" } }
Write-Host 'validate-police-foundation: OK'
