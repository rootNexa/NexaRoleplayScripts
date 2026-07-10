$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_vehicles\server\main.lua') -Raw
foreach ($marker in @('UpdateVehicleState','RecordVehicleDamage','VehicleFuel','VehicleMileage','engine_health','body_health','tank_health','damage_state','maxMileageDelta')) {
    if ($text -notmatch [regex]::Escape($marker)) { throw "Missing vehicle state marker $marker" }
}
Write-Host 'validate-vehicle-state: OK'
