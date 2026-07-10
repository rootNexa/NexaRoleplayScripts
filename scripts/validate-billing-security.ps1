$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-gameplay]/nexa_billing'
$text = (Get-ChildItem -LiteralPath $resource -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
if ($text -match 'TriggerServerEvent|RegisterNetEvent|payload\.total_amount|payload\.account_id|bypass|TODO|FIXME|AddMoney|SetMoney|RemoveMoney') { throw 'Unsafe billing marker found.' }
foreach ($needle in @('calculateItems','normalizeAmount','actorContext','audit(','reason','idempotency_key','exports.nexa_economy:Transfer','overpayment','cancelled')) { if ($text -notmatch [regex]::Escape($needle)) { throw "Missing billing security marker: $needle" } }
Write-Host 'validate-billing-security: ok'
