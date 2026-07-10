$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$org = Join-Path $root '[nexa-gameplay]/nexa_organizations'
$jobs = Join-Path $root '[nexa-gameplay]/nexa_jobs'

foreach ($resource in @($org,$jobs)) {
    foreach ($file in @('fxmanifest.lua','config/shared.lua','shared/constants.lua','server/database.lua','server/main.lua','README.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $resource $file))) {
            throw "Missing foundation file: $resource/$file"
        }
    }
}

$text = (Get-ChildItem -LiteralPath $org,$jobs -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

if ($text -match 'ox_lib|@ox_lib|QBCore|qb-core|qbcore|qbx|qbox|es_extended|ESX|@oxmysql|exports\.oxmysql|MySQL\.|lib\.') {
    throw 'Forbidden framework or direct database-driver reference found.'
}

foreach ($needle in @(
    '090_organizations_foundation',
    '091_jobs_duty_foundation',
    'OrganizationTypes.Register',
    'nexa_organizations',
    'nexa_organization_ranks',
    'nexa_organization_members',
    'nexa_organization_invitations',
    'nexa_job_duty_sessions',
    'nexa_organization_audit',
    "exports('GetOrganization'",
    "exports('GetJob'"
)) {
    if ($text -notmatch [regex]::Escape($needle)) {
        throw "Missing organizations foundation marker: $needle"
    }
}

Write-Host 'validate-organizations-foundation: ok'
