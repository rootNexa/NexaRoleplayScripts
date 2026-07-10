$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_medical') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('ox_lib','@ox_lib','qbcore','qbx','es_extended','MySQL.','exports.oxmysql','lib.')) { if ($text -match [regex]::Escape($forbidden)) { throw "Forbidden medical marker $forbidden" } }
foreach ($marker in @('nexa_medical_states','nexa_medical_injuries','nexa_medical_treatment_sessions','NormalizeDamageEvent','StartTreatmentSession','CompleteTreatmentSession','RespawnAtHospital','CreateMedicalReport')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing medical marker $marker" } }
Write-Host 'validate-medical-foundation: OK'
