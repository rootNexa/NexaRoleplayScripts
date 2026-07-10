$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Read-RepoFile {
    param([string] $RelativePath)

    return Get-Content -LiteralPath (Join-Path $repoRoot $RelativePath) -Raw
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

function Assert-Regex {
    param(
        [string] $Content,
        [string] $Pattern,
        [string] $Message
    )

    if ($Content -notmatch $Pattern) {
        throw "FAIL: $Message"
    }
}

$manifest = Read-RepoFile '[nexa-core]\nexa-core\fxmanifest.lua'
$sessions = Read-RepoFile '[nexa-core]\nexa-core\server\sessions.lua'
$players = Read-RepoFile '[nexa-core]\nexa-core\server\players.lua'
$main = Read-RepoFile '[nexa-core]\nexa-core\server\main.lua'
$api = Read-RepoFile '[nexa-core]\nexa-core\docs\API.md'
$docs = Read-RepoFile 'docs\architecture\core-sessions.md'
$overview = Read-RepoFile 'docs\architecture\core-overview.md'

Assert-Regex $manifest "'server/sessions.lua'[\s\S]*'server/players.lua'" 'sessions.lua must load before players.lua.'

Assert-Contains $sessions 'Nexa.Sessions = Nexa.Sessions or {' 'Nexa.Sessions state missing.'
Assert-Contains $sessions "connecting = 'connecting'" 'connecting state missing.'
Assert-Contains $sessions "authenticated = 'authenticated'" 'authenticated state missing.'
Assert-Contains $sessions "active = 'active'" 'active state missing.'
Assert-Contains $sessions "dropping = 'dropping'" 'dropping state missing.'
Assert-Contains $sessions "closed = 'closed'" 'closed state missing.'
Assert-Contains $sessions "rejected = 'rejected'" 'rejected state missing.'
Assert-Contains $sessions 'local allowedTransitions = {' 'Session state transition table missing.'
Assert-Contains $sessions 'INVALID_STATE_TRANSITION' 'Invalid transition guard missing.'

Assert-Contains $sessions 'function Nexa.Sessions.Create(source, identifiers)' 'Sessions.Create API missing.'
Assert-Contains $sessions 'function Nexa.Sessions.GetBySource(source)' 'Sessions.GetBySource API missing.'
Assert-Contains $sessions 'function Nexa.Sessions.GetById(sessionId)' 'Sessions.GetById API missing.'
Assert-Contains $sessions 'function Nexa.Sessions.GetByLicense(license)' 'Sessions.GetByLicense API missing.'
Assert-Contains $sessions 'function Nexa.Sessions.SetState(sessionId, state)' 'Sessions.SetState API missing.'
Assert-Contains $sessions 'function Nexa.Sessions.Touch(sessionId)' 'Sessions.Touch API missing.'
Assert-Contains $sessions 'function Nexa.Sessions.Close(source, reason)' 'Sessions.Close API missing.'
Assert-Contains $sessions 'function Nexa.Sessions.IsActive(source)' 'Sessions.IsActive API missing.'
Assert-Contains $sessions 'function Nexa.Sessions.GetCount()' 'Sessions.GetCount API missing.'
Assert-Contains $sessions 'function Nexa.Sessions.Cleanup()' 'Sessions.Cleanup API missing.'

Assert-Contains $sessions 'normalizeIdentifierValue' 'Identifier normalization missing.'
Assert-Contains $sessions 'getPrimaryLicense' 'Primary license resolver missing.'
Assert-Contains $sessions 'identifiers.license or identifiers.license2' 'License/license2 priority missing.'
Assert-Contains $sessions "session.dropReason = 'MISSING_LICENSE'" 'Missing license rejection missing.'
Assert-Contains $sessions "return nil, 'MISSING_LICENSE'" 'Missing license error missing.'
Assert-Contains $sessions 'bySource' 'Source binding index missing.'
Assert-Contains $sessions 'byLicense' 'License binding index missing.'
Assert-Contains $sessions 'existingBySource' 'Source reuse handling missing.'
Assert-Contains $sessions 'existingByLicense' 'Duplicate license/reconnect handling missing.'
Assert-Contains $sessions "'reconnect'" 'Reconnect close reason missing.'
Assert-Contains $sessions 'lastActivityAt' 'Last activity timestamp missing.'
Assert-Contains $sessions 'heartbeatAt' 'Heartbeat timestamp missing.'
Assert-Contains $sessions 'dropReason' 'Drop reason missing.'
Assert-Contains $sessions 'maskIp' 'IP masking helper missing.'
Assert-Contains $sessions 'maskIdentifier' 'Identifier masking helper missing.'
Assert-Contains $sessions 'maskedIdentifiers' 'Identifier log masking missing.'
Assert-Contains $sessions 'ipMasked' 'Masked IP metadata missing.'
Assert-Contains $sessions 'GetPlayerEndpoint' 'IP endpoint capture path missing.'
Assert-Contains $sessions 'Nexa.Constants.internalEvents.sessionCreated' 'Session created event missing.'
Assert-Contains $sessions 'Nexa.Constants.internalEvents.sessionRemoved' 'Session removed event missing.'
Assert-Contains $sessions 'publicSession(session)' 'Public session snapshot missing.'
Assert-Contains $sessions 'Nexa.Sessions.byId[sessionId] = nil' 'Terminal session cleanup missing.'

Assert-Contains $players 'Nexa.Sessions.Create(source)' 'Players.Register does not create a session.'
Assert-Contains $players 'session.license' 'Players.Register does not use session license.'
Assert-Contains $players 'sessionId = session.id' 'Player public data does not include session id.'
Assert-Contains $players 'Nexa.Sessions.Close(source, reason)' 'Players.Drop does not close session.'
Assert-Contains $players 'player_registration_failed' 'Player registration failure does not close session.'
Assert-Contains $main 'Nexa.Sessions.GetCount()' 'Core status does not report session count.'

Assert-Contains $api 'Nexa.Sessions.Create(source, identifiers)' 'API docs missing session API.'
Assert-Contains $overview 'core-sessions.md' 'Core overview does not link session docs.'
Assert-Contains $docs 'Eine Session ist keine Account-' 'Session documentation missing account boundary.'
Assert-Contains $docs 'IP-Adressen werden nicht als Account-Identifier verwendet' 'Session documentation missing IP privacy rule.'
Assert-Contains $docs 'Reconnect' 'Session documentation missing reconnect behavior.'

Write-Host 'Core sessions validation passed.'
