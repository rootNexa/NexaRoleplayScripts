$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$harness = Join-Path $root '[nexa-tests]/nexa-economy-runtime-tests'

foreach ($file in @('fxmanifest.lua','server/main.lua','README.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $harness $file))) {
        throw "Missing economy runtime harness file: $file"
    }
}

$text = (Get-ChildItem -LiteralPath $harness -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

foreach ($suite in @('accounts','credit','debit','transfer','reservations','cash','dirtycash','deposit','withdraw','ledger','admin','security','restart','all')) {
    if ($text -notmatch [regex]::Escape($suite)) {
        throw "Missing economy runtime suite: $suite"
    }
}

foreach ($needle in @(
    'nexa_test_economy_runtime',
    'nexa.tests.economy_runtime',
    'exports.nexa_economy:getStatus',
    'exports.nexa_economy:getSchema'
)) {
    if ($text -notmatch [regex]::Escape($needle)) {
        throw "Missing economy runtime marker: $needle"
    }
}

Write-Host 'validate-economy-runtime-harness: ok'
