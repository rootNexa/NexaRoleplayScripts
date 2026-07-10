$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$main = Get-Content -LiteralPath (Join-Path $root '[nexa-gameplay]/nexa_economy/server/main.lua') -Raw

foreach ($needle in @(
    'function Credit',
    'function Debit',
    'function Transfer',
    'function Reserve',
    'function CaptureReservation',
    'function ReleaseReservation',
    'function DepositCash',
    'function WithdrawCash',
    'replayIdempotency',
    'NexaEconomyDatabase.Transaction',
    'withLocks',
    'mutateSingle',
    'compensate'
)) {
    if ($main -notmatch [regex]::Escape($needle)) {
        throw "Missing economy transaction marker: $needle"
    }
}

if ($main -match 'amount%s*[=<>]+%s*0' -and $main -notmatch 'normalizeAmount') {
    throw 'Amount handling does not appear to use normalizeAmount.'
}

Write-Host 'validate-economy-transactions: ok'
