$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$paths = @('[nexa-gameplay]\nexa_vehicles','[nexa-gameplay]\nexa_vehiclekeys','[nexa-gameplay]\nexa_garages','[nexa-gameplay]\nexa_impound')
foreach ($relative in $paths) {
    $path = Join-Path $root $relative
    $text = Get-ChildItem -LiteralPath $path -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
    if ($text -match 'RegisterNetEvent|TriggerServerEvent|AddEventHandler\(''nexa:client') { throw "Unexpected network event pattern in $relative" }
    if ($text -match 'sourcePayload|clientPayload|clientOwner|clientVin|clientPlate|clientNetId') { throw "Client-trusted authority field pattern in $relative" }
    if ($text -match 'MySQL\.') { throw "Direct database driver access in $relative" }
}
Write-Host 'validate-vehicles-security: OK'
