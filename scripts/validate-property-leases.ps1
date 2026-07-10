$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_properties\server\main.lua') -Raw
foreach ($marker in @('Leases.Create','GetActiveLease','leaseAlreadyActive','Rent.Pay','MarkRentPaid','ProcessDueRent','MarkRentOverdue')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing lease marker $marker" } }
Write-Host 'validate-property-leases: OK'
