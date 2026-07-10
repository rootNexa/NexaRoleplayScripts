$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$eventsPath = Join-Path $repoRoot '[nexa-core]\nexa-core\server\events.lua'
$constantsPath = Join-Path $repoRoot '[nexa-core]\nexa-core\shared\constants.lua'
$bootstrapPath = Join-Path $repoRoot '[nexa-core]\nexa-core\server\bootstrap.lua'
$playersPath = Join-Path $repoRoot '[nexa-core]\nexa-core\server\players.lua'
$sessionsPath = Join-Path $repoRoot '[nexa-core]\nexa-core\server\sessions.lua'

$events = Get-Content -LiteralPath $eventsPath -Raw
$constants = Get-Content -LiteralPath $constantsPath -Raw
$bootstrap = Get-Content -LiteralPath $bootstrapPath -Raw
$players = Get-Content -LiteralPath $playersPath -Raw
$sessions = if (Test-Path -LiteralPath $sessionsPath) { Get-Content -LiteralPath $sessionsPath -Raw } else { $players }

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

foreach ($api in @('On', 'Once', 'Off', 'Emit', 'HasListeners', 'GetListenerCount')) {
    Assert-Contains $events "function Nexa.EventBus.$api" "EventBus API missing: $api"
}

Assert-Contains $events 'Nexa.EventBus = Nexa.EventBus or' 'EventBus state missing.'
Assert-Contains $events 'listeners = {}' 'Listener registry missing.'
Assert-Contains $events 'subscriptions = {}' 'Subscription registry missing.'
Assert-Contains $events 'maxListeners = 32' 'Max listener limit missing.'
Assert-Contains $events 'maxDepth = 8' 'Recursion depth limit missing.'
Assert-Contains $events "INTERNAL_EVENT_PATTERN = '^nexa:internal:" 'Internal namespace validation missing.'
Assert-Contains $events 'isValidInternalEventName' 'Namespace validator missing.'
Assert-Contains $events 'makeSubscription' 'Subscription builder missing.'
Assert-Contains $events 'priority = tonumber(options.priority) or 0' 'Priority support missing.'
Assert-Contains $events 'options.async == true' 'Async listener support missing.'
Assert-Contains $events 'once = once == true' 'Once listener support missing.'
Assert-Contains $events "metadata = type(options.metadata) == 'table'" 'Listener metadata missing.'
Assert-Contains $events 'sortListeners(name)' 'Priority sorting missing.'
Assert-Contains $events 'pcall(listener.callback' 'Listener error isolation missing.'
Assert-Contains $events 'eventbus.listener' 'Structured listener error logging missing.'
Assert-Contains $events 'listener.failFast' 'Fail-fast support missing.'
Assert-Contains $events 'dispatchDepth' 'Recursion tracking missing.'
Assert-Contains $events 'RECURSION_LIMIT' 'Recursion limit error missing.'
Assert-Contains $events 'MAX_LISTENERS' 'Max listener error missing.'
Assert-Contains $events 'INVALID_EVENT_NAME' 'Invalid event name handling missing.'
Assert-Contains $events 'CreateThread(function()' 'Async dispatch missing.'
Assert-Contains $events 'Nexa.Events.EmitInternal' 'Compatibility internal emit wrapper missing.'
Assert-Contains $events 'RegisterNetEvent' 'Network events remain separate.'
Assert-Contains $constants 'nexa:internal:core:ready' 'Core ready internal event missing.'
Assert-Contains $constants 'nexa:internal:core:failed' 'Core failed internal event missing.'
Assert-Contains $constants 'nexa:internal:core:stopping' 'Core stopping internal event missing.'
Assert-Contains $constants 'nexa:internal:session:created' 'Session created internal event missing.'
Assert-Contains $constants 'nexa:internal:session:removed' 'Session removed internal event missing.'
Assert-Contains $bootstrap 'Nexa.Constants.internalEvents.coreReady' 'Core ready emit missing.'
Assert-Contains $bootstrap 'Nexa.Constants.internalEvents.coreFailed' 'Core failed emit missing.'
Assert-Contains $bootstrap 'Nexa.Constants.internalEvents.coreStopping' 'Core stopping emit missing.'
Assert-Contains $sessions 'Nexa.Constants.internalEvents.sessionCreated' 'Session created emit missing.'
Assert-Contains $sessions 'Nexa.Constants.internalEvents.sessionRemoved' 'Session removed emit missing.'

Write-Host 'Core event bus validation passed.'
