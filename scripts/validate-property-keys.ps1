$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_propertykeys') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($marker in @('nexa_property_keys','HasPropertyKey','IssuePropertyKey','RevokePropertyKey','SharePropertyKey','nexa_property_doors','SetPropertyDoorLocked')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing key marker $marker" } }
Write-Host 'validate-property-keys: OK'
