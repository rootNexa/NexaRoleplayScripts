$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Read-RepoFile {
    param([string] $RelativePath)

    return Get-Content -LiteralPath (Join-Path $repoRoot $RelativePath) -Raw
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

$constants = Read-RepoFile '[nexa-core]\nexa-core\shared\constants.lua'
$bootstrap = Read-RepoFile '[nexa-core]\nexa-core\server\bootstrap.lua'
$main = Read-RepoFile '[nexa-core]\nexa-core\server\main.lua'
$exports = Read-RepoFile '[nexa-core]\nexa-core\server\exports.lua'
$callbacks = Read-RepoFile '[nexa-core]\nexa-core\server\callbacks.lua'
$events = Read-RepoFile '[nexa-core]\nexa-core\server\events.lua'

$requiredStates = @(
    "created = 'created'",
    "initializing = 'initializing'",
    "initialized = 'initialized'",
    "starting = 'starting'",
    "ready = 'ready'",
    "stopping = 'stopping'",
    "stopped = 'stopped'",
    "failed = 'failed'"
)

foreach ($state in $requiredStates) {
    Assert-Contains $constants $state "Lifecycle state missing: $state"
}

Assert-Contains $constants "'oxmysql'" 'Required dependency oxmysql is missing.'
Assert-Contains $bootstrap 'local allowedTransitions = {' 'Lifecycle transition table missing.'
Assert-Contains $bootstrap 'Ungueltiger Lifecycle-Zustandswechsel blockiert.' 'Invalid transition logging missing.'
Assert-Contains $bootstrap 'Doppelte Core-Initialisierung blockiert.' 'Double initialization guard missing.'
Assert-Contains $bootstrap 'Pflichtabhaengigkeit nicht gestartet' 'Missing dependency handling missing.'
Assert-Contains $bootstrap 'pcall(callback, stage, Nexa.Lifecycle.state)' 'Lifecycle hook error isolation missing.'
Assert-Contains $bootstrap 'function Nexa.Lifecycle.GetState()' 'GetState internal API missing.'
Assert-Contains $bootstrap 'function Nexa.Lifecycle.IsReady()' 'IsReady internal API missing.'
Assert-Contains $bootstrap 'function Nexa.Lifecycle.RegisterLifecycleHook(stage, callback)' 'RegisterLifecycleHook internal API missing.'
Assert-Contains $bootstrap 'function Nexa.Lifecycle.GetStartTimestamp()' 'GetStartTimestamp internal API missing.'
Assert-Contains $bootstrap 'function Nexa.Lifecycle.GetFailureReason()' 'GetFailureReason internal API missing.'
Assert-Contains $bootstrap 'function Nexa.Lifecycle.RequireReady(operation)' 'Readiness guard missing.'
Assert-Contains $bootstrap 'function Nexa.Bootstrap.Start()' 'Bootstrap Start missing.'
Assert-Contains $bootstrap 'function Nexa.Bootstrap.Stop(reason)' 'Bootstrap Stop missing.'
Assert-Contains $bootstrap "AddEventHandler('onResourceStop'" 'Resource stop handler missing.'
Assert-Contains $bootstrap "AddEventHandler('onResourceStart'" 'Dependency start handler missing.'

Assert-Regex $bootstrap "\[states\.created\]\s*=\s*\{[\s\S]*\[states\.initializing\]\s*=\s*true" 'Valid created -> initializing transition missing.'
Assert-Regex $bootstrap "\[states\.initializing\]\s*=\s*\{[\s\S]*\[states\.initialized\]\s*=\s*true" 'Valid initializing -> initialized transition missing.'
Assert-Regex $bootstrap "\[states\.initialized\]\s*=\s*\{[\s\S]*\[states\.starting\]\s*=\s*true" 'Valid initialized -> starting transition missing.'
Assert-Regex $bootstrap "\[states\.starting\]\s*=\s*\{[\s\S]*\[states\.ready\]\s*=\s*true" 'Valid starting -> ready transition missing.'
Assert-Regex $bootstrap "\[states\.ready\]\s*=\s*\{[\s\S]*\[states\.stopping\]\s*=\s*true" 'Valid ready -> stopping transition missing.'
Assert-Regex $bootstrap "\[states\.stopping\]\s*=\s*\{[\s\S]*\[states\.stopped\]\s*=\s*true" 'Valid stopping -> stopped transition missing.'
Assert-Regex $bootstrap "\[states\.initializing\]\s*=\s*\{[\s\S]*\[states\.failed\]\s*=\s*true" 'Failure transition during initialization missing.'

Assert-Contains $main 'RegisterLifecycleHook(Nexa.Constants.lifecycle.stages.starting' 'Starting lifecycle hook registration missing.'
Assert-Contains $main 'RegisterLifecycleHook(Nexa.Constants.lifecycle.stages.stopping' 'Stopping lifecycle hook registration missing.'
Assert-Contains $main 'Nexa.Bootstrap.Start()' 'Resource start does not call bootstrap start.'
Assert-Contains $main "Nexa.Lifecycle.RequireReady('playerJoining')" 'playerJoining readiness guard missing.'

Assert-Contains $exports "Nexa.Lifecycle.RequireReady('export:GetPlayer')" 'GetPlayer readiness guard missing.'
Assert-Contains $exports "Nexa.Lifecycle.RequireReady('export:CreateCharacter')" 'CreateCharacter readiness guard missing.'
Assert-Contains $callbacks "Nexa.Lifecycle.RequireReady(('callback:%s'):format(name))" 'Callback readiness guard missing.'
Assert-Contains $events "Nexa.Lifecycle.RequireReady(('event:%s'):format(name))" 'Event readiness guard missing.'
Assert-Contains $events 'Nexa.Lifecycle.GetState() ~= Nexa.Constants.lifecycle.states.stopping' 'playerDropped stop-state handling missing.'

Write-Host 'Core lifecycle validation passed.'
