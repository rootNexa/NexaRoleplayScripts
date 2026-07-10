$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$resources = @('nexa_vehicles','nexa_vehiclekeys','nexa_garages','nexa_impound')
foreach ($resource in $resources) {
    $path = Join-Path $root "[nexa-gameplay]\$resource"
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing resource $resource" }
    foreach ($file in @('fxmanifest.lua','README.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $path $file))) { throw "Missing $resource/$file" }
    }
    $text = Get-ChildItem -LiteralPath $path -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
    if (($text -join "`n") -match 'ox_lib|@ox_lib|qb%-core|qbcore|qbx|es_extended|ox_inventory|MySQL\.') { throw "Forbidden dependency marker in $resource" }
}
$vehicles = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_vehicles\server\main.lua') -Raw
foreach ($marker in @('CreateVehicle','TransferVehicle','RequestVehicleSpawn','ConfirmVehicleSpawn','UpdateVehicleState','RecordVehicleDamage','GetVehicleFuel','RecordVehicleMileage','ApplyVehicleMods','CreateVehicleInsurance','BeginVehicleLockpick','AdminSetVehicleStatus')) {
    if ($vehicles -notmatch [regex]::Escape($marker)) { throw "Missing vehicle marker $marker" }
}
Write-Host 'validate-vehicles-foundation: OK'
