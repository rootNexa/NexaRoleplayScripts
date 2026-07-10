$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-tests]\nexa-shops-runtime-tests') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($suite in @('definitions','catalog','pricing','stock','buy','sell','organizations','illegal','deliveries','security','restart','all')) { if ($text -notmatch [regex]::Escape($suite)) { throw "Missing shops runtime suite $suite" } }
Write-Host 'validate-shops-runtime-harness: OK'
