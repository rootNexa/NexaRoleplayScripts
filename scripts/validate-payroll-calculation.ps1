$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = (Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_payroll/server/main.lua') -Raw) + (Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_payroll/shared/constants.lua') -Raw)
foreach ($needle in @('DutyTime.Calculate','PayrollCalculator.CalculateSegment','math.floor','minimum_duty_seconds','prorated','interval_seconds','ListDutySessions','PAYROLL_DUTY_INSUFFICIENT','idempotency_key','exports.nexa_economy:Transfer')) { if ($text -notmatch [regex]::Escape($needle)) { throw "Missing payroll calculation marker: $needle" } }
Write-Host 'validate-payroll-calculation: ok'
