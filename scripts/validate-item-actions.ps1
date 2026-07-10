$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$server = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_items/server/main.lua') -Raw
$db = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_items/server/database.lua') -Raw

foreach ($needle in @(
    'ItemActions.RegisterHandler',
    'ItemActions.UnregisterHandler',
    'ItemActions.IsRegistered',
    'ItemActions.Execute',
    'handler_name',
    'cooldown_ms',
    'requires_active_player',
    'requires_quickslot'
)) {
    if (($server + $db) -notmatch [regex]::Escape($needle)) {
        throw "Missing item action marker: $needle"
    }
}

if ($server -match 'TriggerEvent|TriggerClientEvent') {
    throw 'Item action foundation must not dispatch free events.'
}

Write-Host 'validate-item-actions: ok'
