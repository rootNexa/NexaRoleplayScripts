$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-tests]/nexa-playerstate-runtime-tests'
$manifestPath = Join-Path $resource 'fxmanifest.lua'
$serverPath = Join-Path $resource 'server/main.lua'
$readmePath = Join-Path $resource 'README.md'

foreach ($path in @($manifestPath, $serverPath, $readmePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing runtime harness file: $path"
    }
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw
$server = Get-Content -LiteralPath $serverPath -Raw
$readme = Get-Content -LiteralPath $readmePath -Raw

if ($manifest -notmatch 'nexa_playerstate') {
    throw 'Runtime harness must depend on nexa_playerstate.'
}

if ($server -notmatch 'nexa_test_playerstate_runtime') {
    throw 'Runtime test command is missing.'
}

foreach ($suite in @('lifecycle', 'spawn', 'position', 'bucket', 'lifestate', 'identity_spawn', 'disconnect', 'restart', 'security', 'all')) {
    if ($server -notmatch $suite) {
        throw "Runtime suite is missing: $suite"
    }
}

if ($server -notmatch 'IsPlayerAceAllowed') {
    throw 'Runtime command must be ACE guarded.'
}

if ($readme -notmatch 'development') {
    throw 'Runtime harness README must state development-only use.'
}

Write-Host 'validate-playerstate-runtime-harness: ok'
