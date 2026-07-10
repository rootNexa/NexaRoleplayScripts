$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$harnessRoot = Join-Path $repoRoot '[nexa-tests]\nexa-core-runtime-tests'

function Read-RepoFile {
    param([string] $RelativePath)

    return Get-Content -LiteralPath (Join-Path $repoRoot $RelativePath) -Raw
}

function Assert-Path {
    param([string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "FAIL: Missing path: $Path"
    }
}

function Assert-Contains {
    param(
        [string] $Content,
        [string] $Needle,
        [string] $Message
    )

    if (-not $Content.Contains($Needle)) {
        throw "FAIL: $Message"
    }
}

function Assert-NotContains {
    param(
        [string] $Content,
        [string] $Needle,
        [string] $Message
    )

    if ($Content.Contains($Needle)) {
        throw "FAIL: $Message"
    }
}

Assert-Path $harnessRoot
Assert-Path (Join-Path $harnessRoot 'fxmanifest.lua')
Assert-Path (Join-Path $harnessRoot 'server\main.lua')
Assert-Path (Join-Path $harnessRoot 'README.md')

$manifest = Read-RepoFile '[nexa-tests]\nexa-core-runtime-tests\fxmanifest.lua'
$main = Read-RepoFile '[nexa-tests]\nexa-core-runtime-tests\server\main.lua'
$readme = Read-RepoFile '[nexa-tests]\nexa-core-runtime-tests\README.md'
$foundationCfg = Read-RepoFile 'server\foundation.dev.cfg'
$runtimeDocs = Read-RepoFile 'docs\architecture\core-runtime-validation.md'
$boundaryDocs = Read-RepoFile 'docs\architecture\core-domain-boundary-review.md'

Assert-Contains $manifest "dependency 'nexa-core'" 'Runtime harness must depend only on nexa-core.'
Assert-Contains $manifest "server_script 'server/main.lua'" 'Runtime harness server entry missing.'
Assert-NotContains $manifest 'ox_lib' 'Runtime harness must not depend on ox_lib.'
Assert-NotContains $manifest 'qb-core' 'Runtime harness must not depend on qb-core.'
Assert-NotContains $manifest 'qbx' 'Runtime harness must not depend on qbx.'
Assert-NotContains $manifest 'es_extended' 'Runtime harness must not depend on ESX.'

Assert-Contains $main "local COMMAND_NAME = 'nexa_test_core_runtime'" 'Runtime command missing.'
Assert-Contains $main "local COMMAND_ACE = 'nexa.test.core_runtime'" 'ACE guard missing.'
Assert-Contains $main 'IsPlayerAceAllowed(source, COMMAND_ACE)' 'Player command must be ACE guarded.'
Assert-Contains $main "exports[CORE_RESOURCE]:GetCoreObject()" 'Core object export check missing.'
Assert-Contains $main "core.Database.Scalar('SELECT 1'" 'Database health runtime query missing.'
Assert-Contains $main "nexa:internal:runtime_tests:probe" 'EventBus runtime probe missing.'
Assert-Contains $main "core.Cache.GetOrLoad" 'Cache GetOrLoad runtime check missing.'
Assert-Contains $main "core.Callbacks.Register" 'Internal callback runtime check missing.'
Assert-Contains $main "core.Sessions.Create(-1" 'Session invalid source check missing.'
Assert-Contains $main "core.Permissions.GetDecisionTrace" 'Permission decision trace check missing.'
Assert-Contains $main "CreateCharacter = 'skipped: mutates data'" 'Mutating character export skip missing.'
Assert-Contains $main "autoRun = false" 'Harness must not autorun tests.'

Assert-NotContains $main 'RegisterNetEvent' 'Runtime harness must not add network events.'
Assert-NotContains $main 'TriggerClientEvent' 'Runtime harness must not require client trust.'
Assert-NotContains $main 'QBCore' 'Runtime harness must not reference QBCore.'
Assert-NotContains $main 'ESX' 'Runtime harness must not reference ESX.'
Assert-NotContains $main 'ox_lib' 'Runtime harness must not reference ox_lib.'

if ($foundationCfg -match 'ensure\s+nexa-core-runtime-tests') {
    throw 'FAIL: Runtime harness must not be auto-ensured in foundation.dev.cfg.'
}

Assert-Contains $readme 'nexa_test_core_runtime all' 'Harness README must document command.'
Assert-Contains $readme 'Skipped tests are not counted as success.' 'Harness README must document skip semantics.'
Assert-Contains $runtimeDocs 'FXServer executable not available in PATH' 'Runtime validation docs must state local FXServer limitation.'
Assert-Contains $runtimeDocs 'nexa-core-runtime-tests' 'Runtime validation docs must document harness.'
Assert-Contains $boundaryDocs 'CreateCharacter' 'Domain boundary review must cover CreateCharacter.'
Assert-Contains $boundaryDocs 'future owner' 'Domain boundary review must document future ownership.'

$forbidden = @(rg -n 'ox_lib|@ox_lib|QBCore|qb-core|qbcore|qbx|es_extended|ESX|lib\.' $harnessRoot 2>$null)

if ($forbidden.Count -gt 0) {
    throw "FAIL: Forbidden framework reference found in runtime harness:`n$($forbidden -join "`n")"
}

Write-Host 'Core runtime harness validation passed.'
