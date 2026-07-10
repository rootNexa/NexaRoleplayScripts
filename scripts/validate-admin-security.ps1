$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$adminRoot = Join-Path $repoRoot '[nexa-admin]\nexa_admin'

function Read-RepoFile {
    param([string] $RelativePath)
    return Get-Content -LiteralPath (Join-Path $repoRoot $RelativePath) -Raw
}

function Assert-Contains {
    param([string] $Content, [string] $Needle, [string] $Message)
    if (-not $Content.Contains($Needle)) { throw "FAIL: $Message" }
}

$server = Read-RepoFile '[nexa-admin]\nexa_admin\server\main.lua'
$client = Read-RepoFile '[nexa-admin]\nexa_admin\client\main.lua'
$callbacks = Read-RepoFile '[nexa-admin]\nexa_admin\server\callbacks.lua'

$badRoleChecks = @()
$badRoleChecks += @(rg -n 'role\s*==' $adminRoot --glob '*.lua' 2>$null)
$badRoleChecks += @(rg -n 'superadmin|group\.admin|IsPlayerAceAllowed' $adminRoot --glob '*.lua' 2>$null)
if ($badRoleChecks.Count -gt 0) { throw "FAIL: Role or ACE admin shortcut found.`n$($badRoleChecks -join "`n")" }

$todo = @(rg -n 'TODO|FIXME' $adminRoot 2>$null)
if ($todo.Count -gt 0) { throw "FAIL: TODO/FIXME found.`n$($todo -join "`n")" }

Assert-Contains $server 'actorSource = NexaAdminNormalizeSource(actorSource)' 'Actor source normalization missing.'
Assert-Contains $server 'payload = payload or {}' 'Payload normalization missing.'
Assert-Contains $server 'isProtectedTarget' 'Target protection missing.'
Assert-Contains $server 'DropPlayer(target.source' 'DropPlayer should be isolated in ban/kick domain.'
Assert-Contains $callbacks 'RegisterServerCallback' 'Callbacks must use nexa_api.'
Assert-Contains $client 'RegisterNetEvent(NEXA_ADMIN.events.apply' 'Client should only apply server-directed events.'

Write-Host 'Admin security validation passed.'
