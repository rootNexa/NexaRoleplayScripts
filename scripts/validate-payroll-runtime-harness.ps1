$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$harness = Join-Path $root '[nexa-tests]/nexa-payroll-runtime-tests'
foreach ($file in @('fxmanifest.lua','server/main.lua','README.md')) { if (-not (Test-Path -LiteralPath (Join-Path $harness $file))) { throw "Missing payroll harness file: $file" } }
$text = (Get-ChildItem -LiteralPath $harness -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
foreach ($suite in @('policies','dutytime','periods','calculation','runs','economy','government','security','restart','all')) { if ($text -notmatch [regex]::Escape($suite)) { throw "Missing payroll suite: $suite" } }
if ($text -notmatch 'nexa_test_payroll_runtime') { throw 'Missing payroll runtime command.' }
Write-Host 'validate-payroll-runtime-harness: ok'
