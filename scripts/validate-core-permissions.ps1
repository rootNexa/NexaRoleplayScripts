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

function Assert-Regex {
    param(
        [string] $Content,
        [string] $Pattern,
        [string] $Message
    )

    if ($Content -notmatch $Pattern) {
        throw "FAIL: $Message"
    }
}

$permissions = Read-RepoFile '[nexa-core]\nexa-core\server\permissions.lua'
$players = Read-RepoFile '[nexa-core]\nexa-core\server\players.lua'
$main = Read-RepoFile '[nexa-core]\nexa-core\server\main.lua'
$api = Read-RepoFile '[nexa-core]\nexa-core\docs\API.md'
$docs = Read-RepoFile 'docs\architecture\core-permissions.md'

Assert-Contains $permissions 'function Nexa.Permissions.Has(subject, permission, context)' 'Permissions.Has API missing.'
Assert-Contains $permissions 'function Nexa.Permissions.GetAll(subject)' 'Permissions.GetAll API missing.'
Assert-Contains $permissions 'function Nexa.Permissions.AssignRole(subject, role)' 'Permissions.AssignRole API missing.'
Assert-Contains $permissions 'function Nexa.Permissions.RemoveRole(subject, role)' 'Permissions.RemoveRole API missing.'
Assert-Contains $permissions 'function Nexa.Permissions.Grant(subject, permission)' 'Permissions.Grant API missing.'
Assert-Contains $permissions 'function Nexa.Permissions.Deny(subject, permission)' 'Permissions.Deny API missing.'
Assert-Contains $permissions 'function Nexa.Permissions.Revoke(subject, permission)' 'Permissions.Revoke API missing.'
Assert-Contains $permissions 'function Nexa.Permissions.Invalidate(subject)' 'Permissions.Invalidate API missing.'
Assert-Contains $permissions 'function Nexa.Permissions.GetDecisionTrace(subject, permission)' 'Permissions.GetDecisionTrace API missing.'

Assert-Contains $permissions "allow = true" 'Allow effect support missing.'
Assert-Contains $permissions "deny = true" 'Deny effect support missing.'
Assert-Contains $permissions "trace.reason = 'EXPLICIT_DENY'" 'Deny precedence missing.'
Assert-Regex $permissions 'local denyEffect, denyMatch = findRule\(denyRules, normalized\)[\s\S]*local allowEffect, allowMatch = findRule\(allowRules, normalized\)' 'Deny is not evaluated before allow.'
Assert-Contains $permissions 'collectRolePermissions' 'Role inheritance resolver missing.'
Assert-Contains $permissions 'ROLE_INHERITANCE_CYCLE' 'Role inheritance cycle detection missing.'
Assert-Contains $permissions 'nexa_permission_subject_permissions' 'Direct subject permissions table missing.'
Assert-Contains $permissions 'nexa_permission_role_permissions' 'Role permissions table missing.'
Assert-Contains $permissions 'nexa_permission_subject_roles' 'Subject roles table missing.'
Assert-Contains $permissions 'nexa_permission_role_inheritance' 'Role inheritance table missing.'
Assert-Contains $permissions 'Nexa.Permissions.cache' 'Permission cache missing.'
Assert-Contains $permissions 'Nexa.Permissions.traceCache' 'Decision trace cache missing.'
Assert-Contains $permissions 'Nexa.Permissions.cache[subjectKey(resolved)] = nil' 'Subject cache invalidation missing.'
Assert-Contains $permissions 'Nexa.Permissions.cache = {}' 'Global cache invalidation missing.'
Assert-Contains $permissions "permission:find('%*')" 'Wildcard validation missing.'
Assert-Contains $permissions 'wildcardCandidates' 'Wildcard matching missing.'
Assert-Contains $permissions 'IsPlayerAceAllowed' 'ACE fallback missing.'
Assert-Contains $permissions 'ACE_FALLBACK' 'ACE decision trace missing.'
Assert-Contains $permissions 'audit(' 'Audit calls missing.'
Assert-Contains $permissions "permission.check" 'Permission check audit support missing.'
Assert-Contains $permissions "Nexa.Database.RegisterMigration({" 'Permission migration registration missing.'
Assert-Contains $permissions "id = '002_permission_foundation'" 'Permission migration id missing.'
Assert-Contains $permissions "subject_type ENUM('account', 'character')" 'Account/character subject split missing.'
Assert-Contains $permissions 'SELECT permission, value' 'Legacy nexa_permissions fallback missing.'
Assert-Contains $permissions "PERMISSION_PATTERN = '^nexa" 'Nexa permission namespace pattern missing.'

Assert-Contains $players "type = 'account'" 'Players do not load account permission subject.'
Assert-Contains $players 'Nexa.Permissions.Invalidate({' 'Players do not invalidate account permission subject.'
Assert-Contains $main "'nexa.admin.core.status'" 'Core status command does not use Nexa permission namespace.'

Assert-Contains $api 'Nexa.Permissions.GetDecisionTrace(subject, permission)' 'API documentation missing decision trace.'
Assert-Contains $docs 'Deny hat Vorrang' 'Permission documentation missing deny precedence.'
Assert-Contains $docs 'Account- und Character-Permissions' 'Permission documentation missing account/character split.'
Assert-Contains $docs 'Wildcards' 'Permission documentation missing wildcards.'
Assert-Contains $docs 'ACE-Fallback' 'Permission documentation missing ACE fallback.'

Write-Host 'Core permissions validation passed.'
