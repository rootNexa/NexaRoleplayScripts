$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_properties') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($marker in @('PropertyOwnership','Assign','Transfer','ListForOwner','CanManage','nexa_economy','PROPERTY_OWNER_INVALID')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing ownership marker $marker" } }
Write-Host 'validate-property-ownership: OK'
