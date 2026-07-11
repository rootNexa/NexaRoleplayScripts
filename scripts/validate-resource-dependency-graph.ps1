$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$playerstateManifest = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_playerstate/fxmanifest.lua') -Raw
$adminManifest = Get-Content -LiteralPath (Join-Path $root '[nexa-admin]/nexa_admin/fxmanifest.lua') -Raw
$identityManifest = Get-Content -LiteralPath (Join-Path $root '[nexa-core]/nexa-identity/fxmanifest.lua') -Raw
$identityClient = Get-Content -LiteralPath (Join-Path $root '[nexa-core]/nexa-identity/client/main.lua') -Raw
$identityServer = Get-Content -LiteralPath (Join-Path $root '[nexa-core]/nexa-identity/server/main.lua') -Raw
$foundation = Get-Content -LiteralPath (Join-Path $root 'server/foundation.dev.cfg') -Raw

foreach ($dependency in @('nexa-core', 'nexa_identity', 'nexa_characters')) {
    if ($playerstateManifest -notmatch [regex]::Escape("'$dependency'")) {
        throw "nexa_playerstate is missing required dependency: $dependency"
    }
}

foreach ($forbidden in @('nexa_admin', 'nexa-spawn', 'qb-core', 'qbox', 'es_extended', 'ox_lib')) {
    if ($playerstateManifest -match [regex]::Escape($forbidden)) {
        throw "nexa_playerstate has forbidden dependency/reference in manifest: $forbidden"
    }
}

if ($adminManifest -notmatch 'nexa_playerstate') {
    throw 'nexa_admin must depend on nexa_playerstate for recovery/teleport integration.'
}

if ($identityManifest -notmatch 'nexa_playerstate') {
    throw 'nexa-identity must depend on nexa_playerstate for character selection spawn integration.'
}

if ($identityClient -match 'nexa-spawn:client:requestSpawn') {
    throw 'nexa-identity client still calls legacy nexa-spawn.'
}

if ($identityServer -notmatch 'RequestSpawn') {
    throw 'nexa-identity server must call nexa_playerstate RequestSpawn after SelectCharacter.'
}

if ($foundation -notmatch 'ensure nexa_playerstate') {
    throw 'foundation.dev.cfg does not start nexa_playerstate.'
}

if ($foundation -match 'ensure nexa-spawn') {
    throw 'foundation.dev.cfg still starts legacy nexa-spawn next to nexa_playerstate.'
}

$order = ($foundation -split "`r?`n")
$index = @{}
for ($i = 0; $i -lt $order.Count; $i++) {
    $line = $order[$i].Trim()
    if ($line -match '^ensure\s+(.+)$') {
        $index[$Matches[1]] = $i
    }
}

if ($index['nexa_playerstate'] -le $index['nexa_characters']) {
    throw 'nexa_playerstate must start after nexa_characters.'
}

if ($index['nexa_playerstate'] -le $index['nexa_identity']) {
    throw 'nexa_playerstate must start after nexa_identity.'
}

Write-Host 'validate-resource-dependency-graph: ok'
