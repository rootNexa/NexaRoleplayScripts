$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_shops') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
if ($text -match 'RegisterNetEvent|TriggerServerEvent|clientPrice|clientStock|clientAccount|clientInventory|bypass|loadstring') { throw 'Unsafe shops marker' }
foreach ($marker in @('idempotency_key','correlation_id','audit','nexa_economy','nexa_inventory')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing shops security marker $marker" } }
Write-Host 'validate-shops-security: OK'
