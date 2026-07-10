$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot '[nexa-core]\nexa-core\shared\config.lua'
$bootstrapPath = Join-Path $repoRoot '[nexa-core]\nexa-core\server\bootstrap.lua'
$config = Get-Content -LiteralPath $configPath -Raw
$bootstrap = Get-Content -LiteralPath $bootstrapPath -Raw

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

function Assert-Regex {
    param(
        [string] $Content,
        [string] $Pattern,
        [string] $Message
    )

    if ($Content -notmatch $Pattern) {
        throw "FAIL: $Message"
    }
}

foreach ($api in @('Get', 'Has', 'GetSection', 'Validate', 'GetEnvironment', 'GetPublicSnapshot')) {
    Assert-Contains $config "function Config.$api" "Config API missing: $api"
}

Assert-Contains $config 'local schema = {' 'Config schema missing.'
Assert-Contains $config 'local defaults = {' 'Config defaults missing.'
Assert-Contains $config 'local environmentOverrides = {' 'Environment overrides missing.'
Assert-Contains $config "production = {" 'Production environment override missing.'
Assert-Contains $config "test = {" 'Test environment override missing.'
Assert-Contains $config 'getConvarValue' 'Convar integration missing.'
Assert-Contains $config 'validateNode' 'Schema validation function missing.'
Assert-Contains $config 'typeMatches' 'Type validation missing.'
Assert-Contains $config 'nodeSchema.required' 'Required field validation missing.'
Assert-Contains $config 'nodeSchema.min' 'Min range validation missing.'
Assert-Contains $config 'nodeSchema.max' 'Max range validation missing.'
Assert-Contains $config 'UNKNOWN_FIELD' 'Unknown field validation missing.'
Assert-Contains $config 'unknownFields' 'Unknown field mode missing.'
Assert-Contains $config 'Config._ValidateSnapshot' 'Snapshot validator hook missing.'
Assert-Contains $config 'NexaConfig ist immutable.' 'Immutable snapshot guard missing.'
Assert-Contains $config '__newindex = function()' 'Readonly proxy missing.'
Assert-Contains $config '__pairs = function()' 'Readonly proxy iteration missing.'
Assert-Contains $config 'splitPath' 'Path splitting missing.'
Assert-Contains $config 'getPathValue' 'Nested path lookup missing.'
Assert-Contains $config 'makePublicSnapshot' 'Public snapshot builder missing.'
Assert-Contains $config 'removeServerOnlyValues' 'Client-side server-only pruning missing.'
Assert-Contains $config 'serverOnly' 'Server-only schema marker missing.'
Assert-Contains $config 'secret = true' 'Secret schema marker missing.'
Assert-Contains $config 'public = false' 'Non-public schema marker missing.'
Assert-Contains $config 'bootstrapToken' 'Server secret example missing.'
Assert-Contains $config 'Config.GetPublicSnapshot()' 'Public snapshot API missing.'
Assert-Contains $bootstrap 'local function checkConfig()' 'Bootstrap config validation missing.'
Assert-Contains $bootstrap 'Nexa.Config.Validate()' 'Bootstrap does not call Config.Validate.'
Assert-Contains $bootstrap "return false, 'CONFIG_INVALID'" 'Invalid config does not fail bootstrap.'

foreach ($needle in @(
    'debug = {',
    "type = 'boolean'",
    'environment = {',
    "'development', 'staging', 'production', 'test'",
    'maxPerPlayer = {',
    'min = 1',
    'max = 16',
    'timeoutMs = {',
    'min = 100',
    'max = 120000',
    'database = {',
    'slowQueryMs',
    'dbTimeoutMs',
    'dbSlowQueryMs',
    'dbRetryMaxAttempts',
    'dbRetryDelayMs'
)) {
    Assert-Contains $config $needle "Expected schema detail missing: $needle"
}

Write-Host 'Core config validation passed.'
