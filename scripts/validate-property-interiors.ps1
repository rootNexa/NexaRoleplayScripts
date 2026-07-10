$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_property_interiors') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($marker in @('nexa_property_interior_definitions','nexa_property_interior_instances','nexa_property_interior_occupants','entryTokens','entryTokenTtlSeconds','SetPlayerRoutingBucket','ConfirmEnterProperty')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing interior marker $marker" } }
Write-Host 'validate-property-interiors: OK'
