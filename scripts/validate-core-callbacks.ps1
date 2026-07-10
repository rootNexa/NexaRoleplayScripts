$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$serverPath = Join-Path $repoRoot '[nexa-core]\nexa-core\server\callbacks.lua'
$clientPath = Join-Path $repoRoot '[nexa-core]\nexa-core\client\callbacks.lua'
$constantsPath = Join-Path $repoRoot '[nexa-core]\nexa-core\shared\constants.lua'

$server = Get-Content -LiteralPath $serverPath -Raw
$client = Get-Content -LiteralPath $clientPath -Raw
$constants = Get-Content -LiteralPath $constantsPath -Raw

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

foreach ($api in @('Register', 'Unregister', 'Call', 'Has')) {
    Assert-Contains $server "function Nexa.Callbacks.$api" "Internal callback API missing: $api"
}

Assert-Contains $server 'RegisterNetwork' 'Network callback registration missing.'
Assert-Contains $server 'TriggerClient' 'Server-to-client request API missing.'
Assert-Contains $server 'TriggerClientAwait' 'Server-to-client await API missing.'
Assert-Contains $server 'CallAwait' 'Internal await-compatible API missing.'
Assert-Contains $client 'TriggerAwait' 'Client await API missing.'
Assert-Contains $server "CALLBACK_NAME_PATTERN = '^nexa:" 'Callback namespace validation missing.'
Assert-Contains $client "CALLBACK_NAME_PATTERN = '^nexa:" 'Client callback namespace validation missing.'
Assert-Contains $server 'makeRequestId' 'Server request ID generation missing.'
Assert-Contains $client 'makeRequestId' 'Client request ID generation missing.'
Assert-Contains $server 'pendingClient' 'Pending server-to-client requests missing.'
Assert-Contains $client 'pending = {}' 'Pending client-to-server requests missing.'
Assert-Contains $server 'SetTimeout(timeoutMs' 'Server timeout handling missing.'
Assert-Contains $client 'SetTimeout(tonumber(timeoutMs)' 'Client timeout handling missing.'
Assert-Contains $server 'sanitizeForClient' 'Server error sanitizing missing.'
Assert-Contains $client 'sanitizeForServer' 'Client response sanitizing missing.'
Assert-Contains $server 'validatePayload' 'Payload validation missing.'
Assert-Contains $server 'canCall' 'Rate limit helper missing.'
Assert-Contains $server 'RATE_LIMITED' 'Rate limit response missing.'
Assert-Contains $server 'requestSource = source' 'Server source binding missing.'
Assert-Contains $server 'pending.source ~= responseSource' 'Response source binding missing.'
Assert-Contains $server 'callbacks.client_response.source' 'Fake response security logging missing.'
Assert-Contains $server 'callbacks.client_response.unknown' 'Unknown response logging missing.'
Assert-Contains $server 'HANDLER_ERROR' 'Handler error handling missing.'
Assert-Contains $server 'DISCONNECTED' 'Disconnect during request handling missing.'
Assert-Contains $server 'Nexa.Callbacks.pendingClient[requestId] = nil' 'Double response guard missing.'
Assert-Contains $server 'Nexa.Callbacks.networkHandlers[name]' 'Explicit network callback registry missing.'
Assert-Contains $server 'Nexa.Callbacks.handlers[name]' 'Internal callback registry missing.'
Assert-Contains $server 'ok = true' 'Success response shape missing.'
Assert-Contains $server 'ok = false' 'Error response shape missing.'
Assert-Contains $server 'error = {' 'Error object shape missing.'
Assert-Contains $constants 'nexa:core:callbacks:clientRequest' 'Client request event missing.'
Assert-Contains $constants 'nexa:core:callbacks:serverResponse' 'Server response event missing.'

Write-Host 'Core callbacks validation passed.'
