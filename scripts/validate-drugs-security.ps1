$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-criminal]\nexa_drugs') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('clientQuality','clientOutput','real recipe','recipe details','instructions','bypass','loadstring')) { if ($text -match [regex]::Escape($forbidden)) { throw "Unsafe drugs marker $forbidden" } }
foreach ($marker in @('abstract','no_real_recipe','server_calculated','nexa_crafting','idempotency_key')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing drugs security marker $marker" } }
Write-Host 'validate-drugs-security: OK'
