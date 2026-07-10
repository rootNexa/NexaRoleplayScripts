$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$identityRoot = Join-Path $repoRoot '[nexa-gameplay]\nexa_identity'
$charactersRoot = Join-Path $repoRoot '[nexa-gameplay]\nexa_characters'

function Read-RepoFile {
    param([string] $RelativePath)

    return Get-Content -LiteralPath (Join-Path $repoRoot $RelativePath) -Raw
}

function Assert-Path {
    param([string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "FAIL: Missing path: $Path"
    }
}

function Assert-Contains {
    param(
        [string] $Content,
        [string] $Needle,
        [string] $Message
    )

    if (-not $Content.Contains($Needle)) {
        throw "FAIL: $Message"
    }
}

function Assert-NoMatches {
    param(
        [string] $Root,
        [string] $Pattern,
        [string] $Message
    )

    $matches = @(rg -n $Pattern $Root 2>$null)

    if ($matches.Count -gt 0) {
        throw "FAIL: $Message`n$($matches -join "`n")"
    }
}

Assert-Path $identityRoot
Assert-Path $charactersRoot

$identityManifest = Read-RepoFile '[nexa-gameplay]\nexa_identity\fxmanifest.lua'
$identityMain = Read-RepoFile '[nexa-gameplay]\nexa_identity\server\main.lua'
$identityDb = Read-RepoFile '[nexa-gameplay]\nexa_identity\server\database.lua'
$charactersManifest = Read-RepoFile '[nexa-gameplay]\nexa_characters\fxmanifest.lua'
$charactersMain = Read-RepoFile '[nexa-gameplay]\nexa_characters\server\main.lua'
$charactersDb = Read-RepoFile '[nexa-gameplay]\nexa_characters\server\database.lua'
$foundation = Read-RepoFile 'server\foundation.dev.cfg'

Assert-NoMatches $identityRoot 'ox_lib|@ox_lib|QBCore|qb-core|qbcore|qbx|qbox|es_extended|ESX|lib\.|MySQL\.|@oxmysql|exports\.oxmysql|GetPlayerToken|hardware|hwid' 'Forbidden framework, direct oxmysql or hardware identifier reference found in nexa_identity.'
Assert-NoMatches $charactersRoot 'ox_lib|@ox_lib|QBCore|qb-core|qbcore|qbx|qbox|es_extended|ESX|lib\.|MySQL\.|@oxmysql|exports\.oxmysql|GetPlayerToken|hardware|hwid' 'Forbidden framework, direct oxmysql or hardware identifier reference found in nexa_characters.'

Assert-Contains $identityManifest "'nexa-core'" 'nexa_identity must depend on nexa-core.'
Assert-Contains $identityManifest "'GetAccount'" 'nexa_identity GetAccount export missing.'
Assert-Contains $identityManifest "'GetAccountId'" 'nexa_identity GetAccountId export missing.'
Assert-Contains $identityManifest "'IsAccountReady'" 'nexa_identity IsAccountReady export missing.'
Assert-Contains $identityDb '010_identity_accounts' 'Identity migration id missing.'
Assert-Contains $identityDb 'nexa_accounts' 'nexa_accounts table missing.'
Assert-Contains $identityDb 'nexa_account_identifiers' 'nexa_account_identifiers table missing.'
Assert-Contains $identityDb 'nexa_account_review_signals' 'nexa_account_review_signals table missing.'
Assert-Contains $identityMain 'NexaIdentity.ResolveAccount' 'ResolveAccount implementation missing.'
Assert-Contains $identityMain 'EvaluateMultiAccount' 'Multi-account evaluation missing.'
Assert-Contains $identityMain 'DropPlayer' 'Inactive account rejection missing.'
Assert-Contains $identityMain 'maskIdentifier' 'Identifier masking missing.'

Assert-Contains $charactersManifest "'nexa_identity'" 'nexa_characters must depend on nexa_identity.'
Assert-Contains $charactersManifest "'CreateCharacter'" 'nexa_characters CreateCharacter export missing.'
Assert-Contains $charactersManifest "'DeleteCharacter'" 'nexa_characters DeleteCharacter export missing.'
Assert-Contains $charactersDb '020_characters_domain_columns' 'Character migration id missing.'
Assert-Contains $charactersDb 'account_id' 'Character account_id migration missing.'
Assert-Contains $charactersDb 'height' 'Character height migration missing.'
Assert-Contains $charactersDb 'weight' 'Character weight migration missing.'
Assert-Contains $charactersMain 'getAccountIdForSource' 'Server-side account resolution missing.'
Assert-Contains $charactersMain 'ValidateCreate' 'Character create validation missing.'
Assert-Contains $charactersMain 'ValidateUpdate' 'Character update validation missing.'
Assert-Contains $charactersMain 'NEXA_CHARACTERS.errors.notOwned' 'Ownership error handling missing.'
Assert-Contains $charactersMain 'selectionLocks' 'Selection lock missing.'
Assert-Contains $charactersMain 'activeSourceByCharacterId' 'Duplicate active character guard missing.'

$foundationLines = $foundation -split "`r?`n"
$foundationOrder = @{}
for ($i = 0; $i -lt $foundationLines.Count; $i++) {
    if ($foundationLines[$i].Trim() -match '^ensure\s+(.+)$') {
        $foundationOrder[$Matches[1]] = $i
    }
}

if (-not $foundationOrder.ContainsKey('nexa_identity') -or -not $foundationOrder.ContainsKey('nexa_characters') -or -not $foundationOrder.ContainsKey('nexa-character')) {
    throw 'FAIL: foundation.dev.cfg must start nexa_identity, nexa_characters and nexa-character.'
}

if ($foundationOrder['nexa_identity'] -ge $foundationOrder['nexa_characters']) {
    throw 'FAIL: foundation.dev.cfg must start nexa_identity before nexa_characters.'
}

if ($foundationOrder.ContainsKey('nexa_playerstate')) {
    if ($foundationOrder['nexa_characters'] -ge $foundationOrder['nexa_playerstate']) {
        throw 'FAIL: foundation.dev.cfg must start nexa_playerstate after nexa_characters.'
    }

    if ($foundationOrder['nexa_playerstate'] -ge $foundationOrder['nexa-character']) {
        throw 'FAIL: foundation.dev.cfg must start nexa_playerstate before legacy nexa-character.'
    }
} elseif ($foundationOrder['nexa_characters'] -ge $foundationOrder['nexa-character']) {
    throw 'FAIL: foundation.dev.cfg must start nexa_identity and nexa_characters before nexa-character.'
}

foreach ($doc in @(
    'docs\architecture\identity-character-current-state.md',
    'docs\architecture\identity-character-migration-plan.md',
    'docs\architecture\identity-architecture.md',
    'docs\architecture\account-model.md',
    'docs\architecture\identifier-policy.md',
    'docs\architecture\multi-account-policy.md',
    'docs\architecture\character-architecture.md',
    'docs\architecture\character-lifecycle.md',
    'docs\architecture\character-security.md',
    'docs\architecture\character-api-migration.md'
)) {
    Assert-Path (Join-Path $repoRoot $doc)
}

Write-Host 'Identity and character validation passed.'
