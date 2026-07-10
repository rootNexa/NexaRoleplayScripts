$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_crafting') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
if ($text -match 'RegisterNetEvent|TriggerServerEvent|clientOutput|clientQuality|clientCompletion|bypass|loadstring') { throw 'Unsafe crafting marker' }
foreach ($marker in @('quality_result','idempotency_key','correlation_id','nexa_inventory','audit')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing crafting security marker $marker" } }
Write-Host 'validate-crafting-security: OK'
