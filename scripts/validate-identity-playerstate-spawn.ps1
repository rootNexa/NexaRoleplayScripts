$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$identityRoot = Join-Path $root '[nexa-core]\nexa-identity'
$clientPath = Join-Path $identityRoot 'client\main.lua'
$serverPath = Join-Path $identityRoot 'server\main.lua'
$manifestPath = Join-Path $identityRoot 'fxmanifest.lua'
$flowDoc = Join-Path $root 'docs\architecture\identity-playerstate-spawn-flow.md'
$playerstateServerPath = Join-Path $root '[nexa-gameplay]\nexa_playerstate\server\main.lua'

foreach ($path in @($clientPath, $serverPath, $manifestPath, $flowDoc, $playerstateServerPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing identity/playerstate spawn file: $path"
    }
}

$client = Get-Content -LiteralPath $clientPath -Raw
$server = Get-Content -LiteralPath $serverPath -Raw
$manifest = Get-Content -LiteralPath $manifestPath -Raw
$doc = Get-Content -LiteralPath $flowDoc -Raw
$playerstateServer = Get-Content -LiteralPath $playerstateServerPath -Raw

if ($client -match 'nexa-spawn:client:requestSpawn') {
    throw 'Identity client still triggers legacy nexa-spawn.'
}

if ($server -match 'nexa-spawn') {
    throw 'Identity server must not reference legacy nexa-spawn.'
}

foreach ($marker in @("'nexa_playerstate'", 'RequestSpawn', 'pendingSpawnBySource', 'GetActiveCharacter', 'SPAWN_ALREADY_PENDING', 'nexa:player:ready', 'playerDropped', 'onResourceStop')) {
    if (($server + $manifest) -notmatch [regex]::Escape($marker)) {
        throw "Missing identity/playerstate spawn marker: $marker"
    }
}

if ($server -match 'TriggerClientEvent\(EVENTS\.client\.selected[\s\S]{0,120}RequestSpawn') {
    throw 'Client selected event appears before server-side RequestSpawn.'
}

if ($doc -notmatch 'server-authoritative' -or $doc -notmatch 'nexa_playerstate') {
    throw 'Architecture doc must describe server-authoritative playerstate spawn flow.'
}

if ($playerstateServer -notmatch 'state\.state == ''spawn_preparing''' -or $playerstateServer -notmatch 'errors\.spawnPending') {
    throw 'nexa_playerstate RequestSpawn must reject duplicate pending spawn states.'
}

Write-Host 'validate-identity-playerstate-spawn: ok'
