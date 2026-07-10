$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-gameplay]/nexa_payroll'
foreach ($file in @('fxmanifest.lua','config/shared.lua','shared/constants.lua','server/database.lua','server/main.lua','README.md')) { if (-not (Test-Path -LiteralPath (Join-Path $resource $file))) { throw "Missing payroll file: $file" } }
$text = (Get-ChildItem -LiteralPath $resource -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
if ($text -match 'ox_lib|@ox_lib|QBCore|qb-core|qbcore|qbx|qbox|es_extended|ESX|@oxmysql|exports\.oxmysql|MySQL\.|lib\.') { throw 'Forbidden payroll dependency marker found.' }
foreach ($needle in @('100_payroll_foundation','nexa_payroll_policies','nexa_payroll_periods','nexa_payroll_runs','nexa_payroll_entries','nexa_payroll_audit',"exports('ExecutePayroll'",'defaultIntervalSeconds = 7200')) { if ($text -notmatch [regex]::Escape($needle)) { throw "Missing payroll marker: $needle" } }
Write-Host 'validate-payroll-foundation: ok'
