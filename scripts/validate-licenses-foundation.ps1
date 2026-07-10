$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_licenses') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('ox_lib','@ox_lib','qbcore','qbx','es_extended','MySQL.','exports.oxmysql','lib.')) { if ($text -match [regex]::Escape($forbidden)) { throw "Forbidden licenses marker $forbidden" } }
foreach ($marker in @('nexa_license_types','nexa_licenses','nexa_license_history','IssueLicense','SuspendLicense','ReinstateLicense','RevokeLicense','ExpireLicense','ValidateLicense','GetLicenseHistory')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing licenses marker $marker" } }
Write-Host 'validate-licenses-foundation: OK'
