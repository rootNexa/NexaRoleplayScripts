$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-gameplay]/nexa_payroll'
$text = (Get-ChildItem -LiteralPath $resource -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
if ($text -match 'TriggerServerEvent|RegisterNetEvent|payload\.salary|payload\.duty|payload\.account_id|bypass|TODO|FIXME|AddMoney|SetMoney|RemoveMoney') { throw 'Unsafe payroll marker found.' }
foreach ($needle in @('normalizeAmount','actorContext','audit(','reason','idempotency_key','economy_transaction_id','PAYROLL_REASON_REQUIRED')) { if ($text -notmatch [regex]::Escape($needle)) { throw "Missing payroll security marker: $needle" } }
Write-Host 'validate-payroll-security: ok'
