$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-tests]\nexa-crafting-runtime-tests') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($suite in @('recipes','knowledge','stations','inputs','tools','jobs','quality','queue','security','restart','all')) { if ($text -notmatch [regex]::Escape($suite)) { throw "Missing crafting runtime suite $suite" } }
Write-Host 'validate-crafting-runtime-harness: OK'
