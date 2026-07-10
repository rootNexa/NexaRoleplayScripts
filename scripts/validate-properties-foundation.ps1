$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$resources = @('nexa_properties','nexa_propertykeys','nexa_property_interiors','nexa_property_security')
foreach ($resource in $resources) {
    $path = Join-Path $root "[nexa-gameplay]\$resource"
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing resource $resource" }
    $text = Get-ChildItem -LiteralPath $path -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
    if ($text -match 'ox_lib|@ox_lib|qb%-core|qbcore|qbx|es_extended|ox_inventory|MySQL\.') { throw "Forbidden dependency marker in $resource" }
}
foreach ($marker in @('nexa_property_definitions','nexa_properties','nexa_property_ownership_history','nexa_property_leases','nexa_property_residents','nexa_property_audit','GetProperty','BuyProperty','CreateLease','PayRent')) {
    $text = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_properties\server\database.lua') -Raw
    $main = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_properties\server\main.lua') -Raw
    if (($text + $main) -notmatch [regex]::Escape($marker)) { throw "Missing property marker $marker" }
}
Write-Host 'validate-properties-foundation: OK'
