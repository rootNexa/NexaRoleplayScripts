$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$main = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_vehicles\server\main.lua') -Raw
foreach ($marker in @('spawnTokens','spawnTokenTtlSeconds','RequestSpawn','ConfirmSpawn','cleanupSpawnTokens','routing_bucket','source mismatch')) {
    if ($main -notmatch [regex]::Escape($marker)) { throw "Missing spawn marker $marker" }
}
if ($main -match 'Citizen\.InvokeNative') { throw 'Direct native spawn invocation found' }
Write-Host 'validate-vehicle-spawn: OK'
