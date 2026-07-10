$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_properties\server\main.lua') -Raw
foreach ($marker in @('PropertyStorage','OpenPropertyStorage','PropertyWardrobes','CanUsePropertyWardrobe','PropertyGarages','ListPropertyVehicles','nexa_garages')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing storage marker $marker" } }
Write-Host 'validate-property-storage: OK'
