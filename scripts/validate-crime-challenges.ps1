$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$text = Get-Content -LiteralPath (Join-Path $root '[nexa-criminal]\nexa_crime\server\main.lua') -Raw
foreach ($marker in @('CrimeChallenges.Create','CrimeChallenges.Resolve','challenge_id','session_id','server_validated','challengeReplay','challengeExpired')) { if ($text -notmatch [regex]::Escape($marker)) { throw "Missing challenge marker $marker" } }
Write-Host 'validate-crime-challenges: OK'
