$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resource = Join-Path $root '[nexa-gameplay]/nexa_economy'
$main = Get-Content -LiteralPath (Join-Path $resource 'server/main.lua') -Raw
$all = (Get-ChildItem -LiteralPath $resource -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"

if ($all -match 'RegisterNetEvent|TriggerServerEvent|AddMoney|SetMoney|RemoveMoney|payload\.character_id') {
    throw 'Unsafe network or client-trusted money marker found in nexa_economy.'
}

if ($main -match 'Transfer\s*\(\s*payload\.source_account_id') {
    throw 'Client transfer callback must not trust source_account_id.'
}

foreach ($needle in @(
    'getActiveCharacterIdForSource',
    'RegisterNetwork',
    'GetCharacterBankAccount(characterId)',
    'reason =',
    'audit(',
    'normalizeAmount',
    'NexaEconomyConfig.maxAmount'
)) {
    if ($main -notmatch [regex]::Escape($needle)) {
        throw "Missing economy security marker: $needle"
    }
}

Write-Host 'validate-economy-security: ok'
