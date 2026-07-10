$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-tests]\nexa-crime-runtime-tests') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($suite in @('profiles','sessions','challenges','robberies','loot','drugs','blackmarket','moneylaundering','security','restart','all')) { if ($text -notmatch [regex]::Escape($suite)) { throw "Missing crime runtime suite $suite" } }
if ($text -notmatch 'nexa.tests.crime_runtime') { throw 'Runtime harness must be ACE protected' }
Write-Host 'validate-crime-runtime-harness: OK'
