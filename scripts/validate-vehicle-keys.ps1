$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root '[nexa-gameplay]\nexa_vehiclekeys'
$text = Get-ChildItem -LiteralPath $path -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($marker in @('nexa_vehicle_keys','HasVehicleKey','IssueVehicleKey','RevokeVehicleKey','ShareVehicleKey','CanAccessVehicle','SetVehicleLockState')) {
    if ($text -notmatch [regex]::Escape($marker)) { throw "Missing vehicle key marker $marker" }
}
Write-Host 'validate-vehicle-keys: OK'
