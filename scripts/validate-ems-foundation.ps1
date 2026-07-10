$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_ems') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('ox_lib','@ox_lib','qbcore','qbx','es_extended','MySQL.','exports.oxmysql','lib.')) { if ($text -match [regex]::Escape($forbidden)) { throw "Forbidden EMS marker $forbidden" } }
foreach ($marker in @('nexa_ems_inspections','nexa_ems_transports','nexa_ems_hospital_records','InspectPatient','StartPatientTransport','CompletePatientTransport','CreateHospitalRecord')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing EMS marker $marker" } }
Write-Host 'validate-ems-foundation: OK'
