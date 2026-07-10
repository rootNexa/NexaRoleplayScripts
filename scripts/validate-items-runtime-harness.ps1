$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-tests]/nexa-items-runtime-tests'
$manifest = Get-Content -LiteralPath (Join-Path $resource 'fxmanifest.lua') -Raw
$server = Get-Content -LiteralPath (Join-Path $resource 'server/main.lua') -Raw
$readme = Get-Content -LiteralPath (Join-Path $resource 'README.md') -Raw

if ($manifest -notmatch 'nexa_items') {
    throw 'Runtime harness must depend on nexa_items.'
}

if ($server -notmatch 'nexa_test_items_runtime') {
    throw 'Runtime command missing.'
}

foreach ($suite in @('registry','metadata','stacking','durability','expiration','actions','assets','studio','inventory','security','restart','all')) {
    if ($server -notmatch $suite) {
        throw "Runtime suite missing: $suite"
    }
}

if ($server -notmatch 'IsPlayerAceAllowed') {
    throw 'Runtime command must be ACE guarded.'
}

if ($readme -notmatch 'Development-only') {
    throw 'Runtime README must mark the harness as development-only.'
}

Write-Host 'validate-items-runtime-harness: ok'
