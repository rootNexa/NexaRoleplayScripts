$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$harness = Join-Path $root '[nexa-tests]/nexa-billing-runtime-tests'
foreach ($file in @('fxmanifest.lua','server/main.lua','README.md')) { if (-not (Test-Path -LiteralPath (Join-Path $harness $file))) { throw "Missing billing harness file: $file" } }
$text = (Get-ChildItem -LiteralPath $harness -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
foreach ($suite in @('create','payment','cancel','credit','overdue','organization','economy','security','restart','all')) { if ($text -notmatch [regex]::Escape($suite)) { throw "Missing billing suite: $suite" } }
if ($text -notmatch 'nexa_test_billing_runtime') { throw 'Missing billing runtime command.' }
Write-Host 'validate-billing-runtime-harness: ok'
