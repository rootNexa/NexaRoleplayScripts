$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_property_security') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($marker in @('nexa_property_security_state','nexa_property_security_events','nexa_property_burglary_attempts','ArmProperty','DisarmProperty','TriggerPropertyAlarm','BeginPropertyBurglary','ResolvePropertyBurglary')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing security marker $marker" } }
Write-Host 'validate-property-security-system: OK'
