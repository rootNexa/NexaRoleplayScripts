$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Read-RepoFile {
    param([string] $RelativePath)

    return Get-Content -LiteralPath (Join-Path $repoRoot $RelativePath) -Raw
}

function Assert-Contains {
    param(
        [string] $Content,
        [string] $Needle,
        [string] $Message
    )

    if (-not $Content.Contains($Needle)) {
        throw "FAIL: $Message"
    }
}

$constants = Read-RepoFile '[nexa-core]\nexa_permissions\shared\constants.lua'
$service = Read-RepoFile '[nexa-core]\nexa_permissions\server\service.lua'
$doc = Read-RepoFile 'docs\architecture\admin-role-model.md'

foreach ($role in @(
    'owner',
    'co_owner',
    'head_admin',
    'senior_admin',
    'admin',
    'trial_admin',
    'head_support',
    'supporter',
    'support_trainee',
    'developer',
    'qa_tester'
)) {
    Assert-Contains $constants "name = '$role'" "Role $role missing from seed."
    Assert-Contains $doc $role "Role $role missing from admin-role-model.md."
}

Assert-Contains $constants "inherits = 'co_owner'" 'Owner must inherit co_owner.'
Assert-Contains $constants "inherits = 'head_admin'" 'Co-owner must inherit head_admin.'
Assert-Contains $constants "inherits = 'senior_admin'" 'Head admin must inherit senior_admin.'
Assert-Contains $constants "inherits = 'admin'" 'Senior admin must inherit admin.'
Assert-Contains $constants "inherits = 'trial_admin'" 'Admin must inherit trial_admin.'
Assert-Contains $constants "inherits = 'supporter'" 'Head support must inherit supporter.'
Assert-Contains $constants "inherits = 'support_trainee'" 'Supporter must inherit support trainee.'

Assert-Contains $service 'OWNER_PROTECTION' 'Owner protection missing.'
Assert-Contains $service 'LAST_OWNER_PROTECTION' 'Last owner protection missing.'
Assert-Contains $service 'SELF_ELEVATION_FORBIDDEN' 'Self-elevation protection missing.'
Assert-Contains $service 'ROLE_HIERARCHY_FORBIDDEN' 'Role hierarchy protection missing.'
Assert-Contains $service 'countOwners' 'Last owner count check missing.'
Assert-Contains $service 'canManageRole' 'Role management guard missing.'

$roleComparisons = @(rg -n "role\s*==\s*['`"](?:admin|owner|superadmin|supporter|support)['`"]|if\s+\w+Role\s*==" $repoRoot --glob '*.lua' 2>$null)

if ($roleComparisons.Count -gt 0) {
    throw "FAIL: Direct role comparison found; check permissions instead.`n$($roleComparisons -join "`n")"
}

Write-Host 'Admin role validation passed.'
