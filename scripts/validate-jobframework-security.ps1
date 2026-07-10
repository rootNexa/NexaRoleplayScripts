$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-gameplay]\nexa_jobframework') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('clientReward','clientProgress','clientCompletion','bypass','loadstring','RunString','TriggerServerEvent')) {
    if ($text -match [regex]::Escape($forbidden)) { throw "Unsafe jobframework marker $forbidden" }
}
foreach ($marker in @('actorContext','idempotency_key','correlation_id','audit','RegisterNetwork','ResourceNodes.Reserve','rateLimited')) {
    if ($text -notmatch [regex]::Escape($marker)) { throw "Missing jobframework security marker $marker" }
}
Write-Host 'validate-jobframework-security: OK'
