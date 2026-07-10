$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-tests]\nexa-jobframework-runtime-tests') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($suite in @('definitions','sessions','phases','tasks','progress','groups','resource_nodes','rewards','mining','farming','fishing','delivery','trucking','taxi','garbage','mechanic','security','restart','all')) {
    if ($text -notmatch [regex]::Escape($suite)) { throw "Missing jobframework runtime suite $suite" }
}
if ($text -notmatch 'nexa.tests.jobframework_runtime') { throw 'Runtime harness must be ACE protected' }
Write-Host 'validate-jobframework-runtime-harness: OK'
