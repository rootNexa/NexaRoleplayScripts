$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root '[nexa-gameplay]\nexa_garages'
$text = Get-ChildItem -LiteralPath $path -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($marker in @('nexa_garages','RegisterGarage','GetStoredVehicles','StoreVehicle','RetrieveVehicle','organization')) {
    if ($text -notmatch [regex]::Escape($marker)) { throw "Missing garage marker $marker" }
}
Write-Host 'validate-garages: OK'
