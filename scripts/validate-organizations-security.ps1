$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$org = Join-Path $root '[nexa-gameplay]/nexa_organizations'
$jobs = Join-Path $root '[nexa-gameplay]/nexa_jobs'
$text = (Get-ChildItem -LiteralPath $org,$jobs -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
$jobsMain = Get-Content -LiteralPath (Join-Path $jobs 'server/main.lua') -Raw

if ($text -match 'TriggerServerEvent|RegisterNetEvent|setjob|setgrade|payload\.duty\b|bypass|TODO|FIXME') {
    throw 'Unsafe organization/job security marker found.'
}

if ($jobsMain -match 'payload\.organization_id|payload\.rank_id|payload\.character_id') {
    throw 'Jobs network callbacks must not trust organization, rank or character ids.'
}

foreach ($needle in @(
    'activeCharacterId',
    'HasOrganizationPermission',
    'ValidateHierarchy',
    'ownerRankRequired',
    'audit(',
    'reason',
    'playerDropped',
    'onResourceStop'
)) {
    if ($text -notmatch [regex]::Escape($needle)) {
        throw "Missing organizations security marker: $needle"
    }
}

if ($jobsMain -match 'StartDuty\s*\(\s*payload') {
    throw 'Duty must not be set directly from client payload.'
}

Write-Host 'validate-organizations-security: ok'
