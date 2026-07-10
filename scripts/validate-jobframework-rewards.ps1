$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_jobframework') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($marker in @('nexa_job_rewards','Rewards.Get','Rewards.Record','Rewards.Retry','JOB_REWARD_ALREADY_PAID','idempotency_key','nexa_inventory','nexa_economy')) {
    if ($text -notmatch [regex]::Escape($marker)) { throw "Missing reward marker $marker" }
}
Write-Host 'validate-jobframework-rewards: OK'
