$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$harness = Join-Path $root '[nexa-tests]/nexa-organizations-runtime-tests'

foreach ($file in @('fxmanifest.lua','server/main.lua','README.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $harness $file))) {
        throw "Missing organizations runtime harness file: $file"
    }
}

$text = (Get-ChildItem -LiteralPath $harness -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

foreach ($suite in @('organizations','ranks','memberships','duty','economy','storages','garages','modules','creator','security','restart','all')) {
    if ($text -notmatch [regex]::Escape($suite)) {
        throw "Missing organizations runtime suite: $suite"
    }
}

foreach ($needle in @(
    'nexa_test_organizations_runtime',
    'nexa.tests.organizations_runtime',
    'exports[resourceName]:getStatus',
    'exports[resourceName]:getSchema'
)) {
    if ($text -notmatch [regex]::Escape($needle)) {
        throw "Missing organizations runtime marker: $needle"
    }
}

Write-Host 'validate-organizations-runtime-harness: ok'
