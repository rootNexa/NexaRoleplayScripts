$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$main = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_jobs/server/main.lua') -Raw
$constants = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_jobs/shared/constants.lua') -Raw
$config = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_jobs/config/shared.lua') -Raw

foreach ($needle in @(
    'unassigned',
    'assigned',
    'off_duty',
    'on_duty',
    'suspended',
    'unloading',
    'StartDuty',
    'StopDuty',
    'ForceStopDuty',
    'GetActiveDutyMembers',
    'playerDropped',
    'onResourceStop',
    'nexa:internal:job:dutyStarted',
    'nexa:internal:job:dutyStopped',
    'organization.duty.use'
)) {
    if (($main + $constants + $config) -notmatch [regex]::Escape($needle)) {
        throw "Missing jobs duty marker: $needle"
    }
}

Write-Host 'validate-jobs-duty: ok'
