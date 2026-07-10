$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Read-RepoFile {
    param([string] $RelativePath)
    return Get-Content -LiteralPath (Join-Path $repoRoot $RelativePath) -Raw
}

function Assert-Contains {
    param([string] $Content, [string] $Needle, [string] $Message)
    if (-not $Content.Contains($Needle)) { throw "FAIL: $Message" }
}

$server = Read-RepoFile '[nexa-admin]\nexa_admin\server\main.lua'
$manifest = Read-RepoFile '[nexa-admin]\nexa_admin\fxmanifest.lua'

foreach ($action in @(
    'admin.warn',
    'admin.kick',
    'admin.ban.temp',
    'admin.ban.permanent',
    'admin.unban',
    'admin.goto',
    'admin.bring',
    'admin.return',
    'admin.freeze',
    'admin.heal',
    'admin.revive',
    'admin.spectate.start',
    'admin.spectate.stop',
    'admin.noclip.start',
    'admin.noclip.stop',
    'admin.note.create',
    'admin.note.view'
)) {
    Assert-Contains $server "name = '$action'" "Action $action missing."
}

foreach ($export in @(
    'WarnPlayer',
    'KickPlayer',
    'BanPlayer',
    'UnbanPlayer',
    'GoToPlayer',
    'BringPlayer',
    'ReturnPlayer',
    'SetPlayerFrozen',
    'HealPlayer',
    'RevivePlayer',
    'StartSpectate',
    'StopSpectate',
    'StartNoclip',
    'StopNoclip',
    'CreateAdminNote',
    'ListAdminNotes',
    'GetAdminActionState'
)) {
    Assert-Contains $manifest "'$export'" "Export $export missing from manifest."
    Assert-Contains $server "function $export" "Function $export missing."
}

Assert-Contains $server 'reasonRequired = true' 'Reason requirement missing.'
Assert-Contains $server 'ensureDuty' 'Duty check missing.'
Assert-Contains $server 'checkRateLimit' 'Rate limit check missing.'
Assert-Contains $server 'auditAction' 'Action audit missing.'

Write-Host 'Admin actions validation passed.'
