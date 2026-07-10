$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$permissionsRoot = Join-Path $repoRoot '[nexa-core]\nexa_permissions'

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

function Assert-NoMatches {
    param(
        [string] $Root,
        [string] $Pattern,
        [string] $Message
    )

    $matches = @(rg -n $Pattern $Root 2>$null)

    if ($matches.Count -gt 0) {
        throw "FAIL: $Message`n$($matches -join "`n")"
    }
}

if (-not (Test-Path -LiteralPath $permissionsRoot)) {
    throw "FAIL: nexa_permissions resource missing."
}

$manifest = Read-RepoFile '[nexa-core]\nexa_permissions\fxmanifest.lua'
$service = Read-RepoFile '[nexa-core]\nexa_permissions\server\service.lua'
$main = Read-RepoFile '[nexa-core]\nexa_permissions\server\main.lua'
$constants = Read-RepoFile '[nexa-core]\nexa_permissions\shared\constants.lua'
$readme = Read-RepoFile '[nexa-core]\nexa_permissions\README.md'

Assert-NoMatches $permissionsRoot 'ox_lib|@ox_lib|QBCore|qb-core|qbcore|qbx|qbox|es_extended|ESX|@oxmysql|MySQL\.|exports\.oxmysql|GetPlayerToken|hardware_id|hwid' 'Forbidden framework, direct oxmysql include/API or hardware permission reference found in nexa_permissions.'
Assert-NoMatches $permissionsRoot 'discord.*role|role.*discord|\bip\b.*permission|permission.*\bip\b' 'Discord/IP permission source found in nexa_permissions.'

Assert-Contains $manifest "'nexa-core'" 'nexa_permissions must depend on nexa-core.'
Assert-Contains $manifest "'nexa_identity'" 'nexa_permissions must depend on nexa_identity.'
Assert-Contains $manifest "'AssignRole'" 'AssignRole export missing.'
Assert-Contains $manifest "'RemoveRole'" 'RemoveRole export missing.'
Assert-Contains $manifest "'GrantPermission'" 'GrantPermission export missing.'
Assert-Contains $manifest "'DenyPermission'" 'DenyPermission export missing.'
Assert-Contains $manifest "'RevokePermission'" 'RevokePermission export missing.'
Assert-Contains $manifest "'ListRegisteredPermissions'" 'ListRegisteredPermissions export missing.'

Assert-Contains $service 'nexa_registered_permissions' 'Registered permission table missing.'
Assert-Contains $service 'nexa_account_roles' 'Account role table missing.'
Assert-Contains $service 'nexa_character_roles' 'Character role table missing.'
Assert-Contains $service 'nexa_permission_audit' 'Permission audit table missing.'
Assert-Contains $service 'nexa_admin_duty' 'Admin duty table missing.'
Assert-Contains $service 'core.Database.RegisterMigration' 'Migration must be registered through nexa-core database layer.'
Assert-Contains $service 'core.Database.RunMigrations' 'nexa_permissions migration runner missing.'
Assert-Contains $service 'NexaPermissionsNormalizePermission' 'Permission normalization missing.'
Assert-Contains $service 'PERMISSION_NOT_FOUND' 'Unknown permission handling missing.'
Assert-Contains $service 'ACTOR_NOT_AUTHORIZED' 'Actor authorization handling missing.'

Assert-Contains $main 'RegisterCommand(' 'Permission development commands missing.'
Assert-Contains $main 'playerDropped' 'Duty disconnect cleanup missing.'
Assert-Contains $main 'onResourceStop' 'Duty resource-stop cleanup missing.'

Assert-Contains $constants "name = 'nexa.permissions.assign_role'" 'Permission assignment catalog entry missing.'
Assert-Contains $constants "name = 'nexa.permissions.manage_owner'" 'Owner management catalog entry missing.'
Assert-Contains $constants 'NEXA_PERMISSIONS.rolePermissions' 'Role permission seed missing.'

Assert-Contains $readme 'does not load the oxmysql Lua include directly' 'README must document no direct oxmysql usage.'

git -C $repoRoot diff --check

Write-Host 'Permission validation passed.'
