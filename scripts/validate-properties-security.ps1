$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$paths = @('[nexa-gameplay]\nexa_properties','[nexa-gameplay]\nexa_propertykeys','[nexa-gameplay]\nexa_property_interiors','[nexa-gameplay]\nexa_property_security')
foreach ($relative in $paths) {
    $text = Get-ChildItem -LiteralPath (Join-Path $root $relative) -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
    if ($text -match 'RegisterNetEvent|TriggerServerEvent|clientOwner|clientLease|clientBucket|clientKey|bypass') { throw "Unsafe network/client trust marker in $relative" }
    if ($text -match 'MySQL\.|oxmysql') { throw "Direct database access marker in $relative" }
}
Write-Host 'validate-properties-security: OK'
