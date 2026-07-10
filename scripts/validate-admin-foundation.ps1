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

function Assert-NoMatches {
    param([string] $Root, [string] $Pattern, [string] $Message)
    $matches = @(rg -n $Pattern $Root 2>$null)
    if ($matches.Count -gt 0) { throw "FAIL: $Message`n$($matches -join "`n")" }
}

$manifest = Read-RepoFile '[nexa-admin]\nexa_admin\fxmanifest.lua'
$server = Read-RepoFile '[nexa-admin]\nexa_admin\server\main.lua'

Assert-NoMatches $adminRoot 'ox_lib|@ox_lib|lib\.|MySQL\.|@oxmysql|exports\.oxmysql|QBCore|qb-core|qbcore|qbx|qbox|es_extended|ESX' 'Forbidden framework or direct DB dependency found in nexa_admin.'
Assert-Contains $manifest "'nexa-core'" 'nexa_admin must depend on nexa-core.'
Assert-Contains $manifest "'nexa_identity'" 'nexa_admin must depend on nexa_identity.'
Assert-Contains $manifest "'nexa_characters'" 'nexa_admin must depend on nexa_characters.'
Assert-Contains $manifest "'nexa_permissions'" 'nexa_admin must depend on nexa_permissions.'
Assert-Contains $server "id = '040_admin_foundation'" 'Admin migration id missing.'
Assert-Contains $server 'nexa_admin_warnings' 'Warnings table missing.'
Assert-Contains $server 'nexa_admin_bans' 'Bans table missing.'
Assert-Contains $server 'nexa_admin_notes' 'Notes table missing.'
Assert-Contains $server 'nexa_admin_actions' 'Actions audit table missing.'
Assert-Contains $server 'exports.nexa_permissions:Has' 'Permission checks must use nexa_permissions.'

git -C $repoRoot diff --check
Write-Host 'Admin foundation validation passed.'
