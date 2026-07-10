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

$service = Read-RepoFile '[nexa-core]\nexa_permissions\server\service.lua'
$main = Read-RepoFile '[nexa-core]\nexa_permissions\server\main.lua'
$auditDoc = Read-RepoFile 'docs\architecture\permission-audit.md'
$dutyDoc = Read-RepoFile 'docs\architecture\admin-duty.md'

Assert-Contains $service 'function NexaPermissions.RegisterPermission' 'RegisterPermission missing.'
Assert-Contains $service 'function NexaPermissions.RegisterRole' 'RegisterRole missing.'
Assert-Contains $service 'function NexaPermissions.AssignRole' 'AssignRole missing.'
Assert-Contains $service 'function NexaPermissions.RemoveRole' 'RemoveRole missing.'
Assert-Contains $service 'function NexaPermissions.GrantPermission' 'GrantPermission missing.'
Assert-Contains $service 'function NexaPermissions.DenyPermission' 'DenyPermission missing.'
Assert-Contains $service 'function NexaPermissions.RevokePermission' 'RevokePermission missing.'
Assert-Contains $service 'requireReason' 'Audit reason guard missing.'
Assert-Contains $service 'AUDIT_REASON_REQUIRED' 'Missing reason error code missing.'
Assert-Contains $service 'protectedFailure' 'Protected failure audit helper missing.'
Assert-Contains $service 'audit(' 'Audit helper calls missing.'
Assert-Contains $service 'reason VARCHAR(512) NOT NULL' 'Audit table must require reason.'
Assert-Contains $service 'correlation_id VARCHAR(96)' 'Correlation ID field missing.'
Assert-Contains $service 'source_resource VARCHAR(64) NOT NULL' 'Source resource audit field missing.'
Assert-Contains $service 'result VARCHAR(32) NOT NULL' 'Audit result field missing.'

Assert-Contains $service 'NexaPermissions.AdminDuty.Set' 'Admin duty Set missing.'
Assert-Contains $service 'NexaPermissions.AdminDuty.Get' 'Admin duty Get missing.'
Assert-Contains $service 'NexaPermissions.AdminDuty.IsOnDuty' 'Admin duty IsOnDuty missing.'
Assert-Contains $service 'NexaPermissions.AdminDuty.Clear' 'Admin duty Clear missing.'
Assert-Contains $main 'ClearAdminDuty' 'ClearAdminDuty export wrapper missing.'

Assert-Contains $auditDoc 'Mutating actions require a non-empty reason.' 'Audit documentation missing reason rule.'
Assert-Contains $dutyDoc 'Disconnect clears in-memory duty.' 'Duty documentation missing disconnect rule.'

Write-Host 'Permission audit validation passed.'
