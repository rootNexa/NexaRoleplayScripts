$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-gameplay]/nexa_playerstate'
$server = Get-Content -LiteralPath (Join-Path $resource 'server/main.lua') -Raw
$client = Get-Content -LiteralPath (Join-Path $resource 'client/main.lua') -Raw

if ($server -notmatch 'spawnTokens') {
    throw 'Spawn token store is missing.'
}

foreach ($guard in @('tokenInvalid', 'tokenExpired', 'tokenUsed', 'pending.source ~= playerSource')) {
    if ($server -notmatch $guard) {
        throw "Missing spawn token guard: $guard"
    }
}

if ($server -notmatch 'local playerSource = source') {
    throw 'Network events must bind to the real FiveM source.'
}

$networkHandlers = [regex]::Matches($server, 'RegisterNetEvent\(NEXA_PLAYERSTATE\.events\.[\s\S]*?\nend\)')
foreach ($handler in $networkHandlers) {
    if ($handler.Value -match 'payload\.source') {
        throw 'Server appears to trust client-provided source in a network payload.'
    }
}

if ($client -match 'SetPlayerRoutingBucket|SetRoutingBucket') {
    throw 'Client must not set routing bucket.'
}

if ($client -match 'TriggerServerEvent\(.*active') {
    throw 'Client must not mark itself active.'
}

if ($server -match 'exports\.oxmysql|MySQL\.|mysql-async') {
    throw 'Direct database access found in playerstate server code.'
}

Write-Host 'validate-playerstate-security: ok'
