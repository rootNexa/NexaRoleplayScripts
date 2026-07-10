$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-gameplay]/nexa_playerstate'
$requiredFiles = @(
    'fxmanifest.lua',
    'config/shared.lua',
    'shared/constants.lua',
    'server/validators.lua',
    'server/main.lua',
    'client/main.lua',
    'README.md'
)

foreach ($file in $requiredFiles) {
    $path = Join-Path $resource $file
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing nexa_playerstate file: $file"
    }
}

$manifest = Get-Content -LiteralPath (Join-Path $resource 'fxmanifest.lua') -Raw
foreach ($export in @(
    'GetPlayerState',
    'IsPlayerActive',
    'IsPlayerReadyForGameplay',
    'GetActiveCharacter',
    'GetLastPosition',
    'RequestSpawn',
    'RegisterSpawnProvider'
)) {
    if ($manifest -notmatch [regex]::Escape("'$export'")) {
        throw "Missing server export in fxmanifest.lua: $export"
    }
}

$all = Get-ChildItem -LiteralPath $resource -Recurse -File | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw
}
$joined = $all -join "`n"

if ($joined -match 'ox_lib|@ox_lib|qbcore|qb-core|qbox|es_extended|esx') {
    throw 'Forbidden framework dependency found in nexa_playerstate.'
}

if ($joined -match 'exports\.oxmysql|MySQL\.|mysql-async') {
    throw 'Direct database access found in nexa_playerstate.'
}

foreach ($table in @('nexa_character_positions', 'nexa_character_states')) {
    if ($joined -notmatch $table) {
        throw "Missing migration table reference: $table"
    }
}

Write-Host 'validate-playerstate-foundation: ok'
