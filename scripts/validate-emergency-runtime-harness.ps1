$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-tests]\nexa-emergency-runtime-tests') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($suite in @('medical','ems','police','dispatch','licenses','evidence','mdt','restart','all')) { if ($text -notmatch [regex]::Escape($suite)) { throw "Missing emergency runtime suite $suite" } }
if ($text -notmatch 'nexa.tests.emergency_runtime') { throw 'Runtime harness must be ACE protected' }
Write-Host 'validate-emergency-runtime-harness: OK'
