$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_legaljobs') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('ox_lib','@ox_lib','qb-core','qbcore','qbx','es_extended','MySQL.','exports.oxmysql','lib.')) {
    if ($text -match [regex]::Escape($forbidden)) { throw "Forbidden legaljobs dependency marker $forbidden" }
}
foreach ($marker in @('legal_mining','legal_farming','legal_fishing','legal_delivery','legal_trucking','legal_taxi','legal_garbage','legal_mechanic_service','legal_courier','legal_logistics','GetLegalJobDefinitions')) {
    if ($text -notmatch [regex]::Escape($marker)) { throw "Missing legaljobs marker $marker" }
}
Write-Host 'validate-legaljobs: OK'
