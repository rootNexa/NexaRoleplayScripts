$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_jobframework\server\main.lua') -Raw
foreach ($marker in @('Progress.Get','Progress.Apply','Progress.SetValidated','Progress.Complete','Progress.Validate','NexaJobFrameworkDatabase.UpsertProgress','NEXA_JOB_PROGRESS_STATUS.completed','taskCompleted')) {
    if ($text -notmatch [regex]::Escape($marker)) { throw "Missing progress marker $marker" }
}
Write-Host 'validate-jobframework-progress: OK'
