$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root '[nexa-gameplay]\nexa_jobframework'
$text = Get-ChildItem -LiteralPath $path -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
if ($text -match 'ox_lib|@ox_lib|qb-core|qbcore|qbx|es_extended|MySQL\.|exports\.oxmysql|lib\.') { throw 'Forbidden jobframework dependency marker' }
foreach ($marker in @('nexa_job_definitions','nexa_job_phases','nexa_job_tasks','nexa_job_sessions','nexa_job_task_progress','nexa_job_rewards','nexa_job_cooldowns','nexa_job_resource_nodes','nexa_job_audit','JobTypes','TaskTypes','GetJobDefinition','StartJob','CompleteJobTask','RegisterResourceNode','RegisterProductionChain')) {
    if ($text -notmatch [regex]::Escape($marker)) { throw "Missing jobframework marker $marker" }
}
Write-Host 'validate-jobframework-foundation: OK'
