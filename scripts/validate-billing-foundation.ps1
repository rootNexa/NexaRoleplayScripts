$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-gameplay]/nexa_billing'
foreach ($file in @('fxmanifest.lua','config/shared.lua','shared/constants.lua','server/database.lua','server/main.lua','README.md')) { if (-not (Test-Path -LiteralPath (Join-Path $resource $file))) { throw "Missing billing file: $file" } }
$text = (Get-ChildItem -LiteralPath $resource -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
if ($text -match 'ox_lib|@ox_lib|QBCore|qb-core|qbcore|qbx|qbox|es_extended|ESX|@oxmysql|exports\.oxmysql|MySQL\.|lib\.') { throw 'Forbidden billing dependency marker found.' }
foreach ($needle in @('101_billing_foundation','nexa_invoices','nexa_invoice_items','nexa_invoice_payments','nexa_invoice_audit','calculateItems',"exports('PayInvoice'",'economy_transaction_id')) { if ($text -notmatch [regex]::Escape($needle)) { throw "Missing billing marker: $needle" } }
Write-Host 'validate-billing-foundation: ok'
