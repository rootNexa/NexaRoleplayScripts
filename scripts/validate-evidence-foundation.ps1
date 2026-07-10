$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-ChildItem -LiteralPath (Join-Path $root '[nexa-criminal]\nexa_evidence') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
foreach ($forbidden in @('ox_lib','@ox_lib','ox_inventory','qbcore','qbx','es_extended','MySQL.','exports.oxmysql','lib.')) { if ($text -match [regex]::Escape($forbidden)) { throw "Forbidden evidence marker $forbidden" } }
foreach ($marker in @('nexa_evidence_records','nexa_evidence_traces','nexa_evidence_locker','CollectEvidence','CreateTrace','StoreEvidenceLocker')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing evidence marker $marker" } }
Write-Host 'validate-evidence-foundation: OK'
