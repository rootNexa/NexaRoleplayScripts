$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $repoRoot '[nexa-tests]\nexa-admin-runtime-tests'

function Read-RepoFile {
    param([string] $RelativePath)
    return Get-Content -LiteralPath (Join-Path $repoRoot $RelativePath) -Raw
}

if (-not (Test-Path -LiteralPath $testRoot)) {
    throw 'FAIL: nexa-admin-runtime-tests resource missing.'
}

$manifest = Read-RepoFile '[nexa-tests]\nexa-admin-runtime-tests\fxmanifest.lua'
$server = Read-RepoFile '[nexa-tests]\nexa-admin-runtime-tests\server\main.lua'
$readme = Read-RepoFile '[nexa-tests]\nexa-admin-runtime-tests\README.md'

if (-not $manifest.Contains("'nexa_admin'")) { throw 'FAIL: Runtime harness must depend on nexa_admin.' }
if (-not $server.Contains('nexa_test_admin_runtime')) { throw 'FAIL: Runtime command missing.' }
if (-not $server.Contains('nexa.tests.admin_runtime')) { throw 'FAIL: Runtime command ACE guard missing.' }
if (-not $server.Contains("'open'")) { throw 'FAIL: Runtime-open status missing.' }
if (-not $readme.Contains('Do not autostart')) { throw 'FAIL: Runtime README must warn against autostart.' }

Write-Host 'Admin runtime harness validation passed.'
