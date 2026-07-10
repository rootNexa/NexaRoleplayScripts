$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-criminal]\nexa_blackmarket') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($marker in @('nexa_moneylaundering_jobs','BeginMoneyLaundering','GetMoneyLaunderingJob','fee_amount','payout_amount','idempotency_key','saga')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing laundering marker $marker" } }
Write-Host 'validate-moneylaundering: OK'
