$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_dispatch') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('ox_lib','@ox_lib','qbcore','qbx','es_extended','MySQL.','exports.oxmysql','lib.')) { if ($text -match [regex]::Escape($forbidden)) { throw "Forbidden dispatch marker $forbidden" } }
foreach ($marker in @('nexa_dispatch_calls','nexa_dispatch_units','CreateDispatchCall','AssignDispatchUnit','SetUnitStatus','RegisterDispatchAdapter')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing dispatch marker $marker" } }
Write-Host 'validate-dispatch-foundation: OK'
