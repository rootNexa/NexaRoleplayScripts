$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root '[nexa-gameplay]\nexa_impound'
$text = Get-ChildItem -LiteralPath $path -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($marker in @('nexa_vehicle_impounds','ImpoundVehicle','ReleaseVehicle','GetImpound','ListImpounds','MarkVehicleImpounded')) {
    if ($text -notmatch [regex]::Escape($marker)) { throw "Missing impound marker $marker" }
}
Write-Host 'validate-vehicle-impound: OK'
