$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root '[nexa-tests]\nexa-vehicles-runtime-tests'
if (-not (Test-Path -LiteralPath $path)) { throw 'Missing runtime harness resource' }
$text = Get-ChildItem -LiteralPath $path -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($suite in @('definitions','creation','spawn','despawn','keys','access','garages','state','damage','fuel','mileage','insurance','mods','impound','theft','security','restart','all')) {
    if ($text -notmatch [regex]::Escape($suite)) { throw "Missing runtime suite $suite" }
}
if ($text -notmatch 'nexa_test_vehicles_runtime') { throw 'Missing runtime command' }
Write-Host 'validate-vehicles-runtime-harness: OK'
