$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-criminal]\nexa_crime') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('clientSuccess','clientLoot','clientQuality','clientReputation','clientHeat','clientPoliceCount','bypass','loadstring','RunString')) { if ($text -match [regex]::Escape($forbidden)) { throw "Unsafe crime marker $forbidden" } }
foreach ($marker in @('actorContext','reasonRequired','idempotency_key','correlation_id','audit','RegisterNetwork','Responder')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing crime security marker $marker" } }
Write-Host 'validate-crime-security: OK'
