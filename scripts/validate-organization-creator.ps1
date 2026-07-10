$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$orgText = (Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_organizations') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

foreach ($needle in @(
    'NexaOrganizationsConfig.minRanks',
    'NexaOrganizationsConfig.maxRanks',
    'is_owner_rank',
    'OrganizationModules.Enable',
    'OrganizationStorages.Register',
    'OrganizationGarages.Register',
    'OrganizationAccounts.Ensure',
    'Activate',
    'rankLimitMin',
    'rankLimitMax',
    'ownerRankRequired'
)) {
    if ($orgText -notmatch [regex]::Escape($needle)) {
        throw "Missing organization creator marker: $needle"
    }
}

Write-Host 'validate-organization-creator: ok'
