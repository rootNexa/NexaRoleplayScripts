$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$server = Join-Path $root '[nexa-gameplay]/nexa_playerstate/server/main.lua'
$constants = Join-Path $root '[nexa-gameplay]/nexa_playerstate/shared/constants.lua'
$client = Join-Path $root '[nexa-gameplay]/nexa_playerstate/client/main.lua'

$serverText = Get-Content -LiteralPath $server -Raw
$constantsText = Get-Content -LiteralPath $constants -Raw
$clientText = Get-Content -LiteralPath $client -Raw

foreach ($state in @(
    'connected',
    'session_ready',
    'identity_ready',
    'character_selection',
    'character_selected',
    'state_loading',
    'spawn_preparing',
    'spawn_authorized',
    'spawning',
    'active',
    'unloading',
    'failed'
)) {
    if ($constantsText -notmatch $state) {
        throw "Missing lifecycle state in constants: $state"
    }
}

foreach ($symbol in @(
    'PlayerStateTransition',
    'PlayerStateCanTransition',
    'PlayerStateFail',
    'PlayerStateUnload',
    'GetTransitionHistory',
    'RequestSpawn'
)) {
    if ($serverText -notmatch $symbol) {
        throw "Missing lifecycle function: $symbol"
    }
}

foreach ($event in @('spawnExecute', 'spawnConfirm', 'positionSnapshot')) {
    if ($constantsText -notmatch $event) {
        throw "Missing playerstate event constant: $event"
    }
}

if ($clientText -notmatch 'TriggerServerEvent\(NEXA_PLAYERSTATE\.events\.spawnConfirm') {
    throw 'Client spawn confirmation event is missing.'
}

if ($serverText -notmatch 'TriggerClientEvent\(NEXA_PLAYERSTATE\.events\.spawnExecute') {
    throw 'Server spawn authorization event is missing.'
}

Write-Host 'validate-playerstate-lifecycle: ok'
