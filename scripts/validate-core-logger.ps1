$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$loggerPath = Join-Path $repoRoot '[nexa-core]\nexa-core\shared\init.lua'
$content = Get-Content -LiteralPath $loggerPath -Raw

function Assert-Contains {
    param(
        [string] $Needle,
        [string] $Message
    )

    if (-not $content.Contains($Needle)) {
        throw "FAIL: $Message"
    }
}

function Assert-Regex {
    param(
        [string] $Pattern,
        [string] $Message
    )

    if ($content -notmatch $Pattern) {
        throw "FAIL: $Message"
    }
}

foreach ($level in @('debug', 'info', 'warn', 'error', 'audit', 'security')) {
    Assert-Regex "$level\s*=\s*\d+" "Log level missing: $level"
}

foreach ($method in @('Debug', 'Info', 'Warn', 'Error', 'Audit', 'Security', 'WithContext', 'SetLevel')) {
    Assert-Contains "function Nexa.Logger.$method" "Logger API missing: $method"
}

Assert-Contains 'timestamp = os.date' 'Timestamp missing from log entry.'
Assert-Contains 'level = level' 'Level missing from log entry.'
Assert-Contains 'resource = GetCurrentResourceName' 'Resource missing from log entry.'
Assert-Contains 'module = extractContextField' 'Module extraction missing from log entry.'
Assert-Contains 'category = type(category)' 'Category missing from log entry.'
Assert-Contains 'message = type(message)' 'Message missing from log entry.'
Assert-Contains 'context = safeContext' 'Structured context missing from log entry.'
Assert-Contains "source = extractContextField(safeContext, 'source')" 'Source extraction missing.'
Assert-Contains "characterId = extractContextField(safeContext, 'characterId')" 'Character ID extraction missing.'
Assert-Contains "correlationId = extractContextField(safeContext, 'correlationId')" 'Correlation ID extraction missing.'

foreach ($sensitive in @('password', 'token', 'secret', 'authorization', 'cookie', 'session')) {
    Assert-Contains "'$sensitive'" "Sensitive key pattern missing: $sensitive"
}

Assert-Contains "return '<redacted>'" 'Sensitive value redaction missing.'
Assert-Contains "return ('%s.%s.x.x'):format(first, second)" 'IP masking missing.'
Assert-Contains "return '<cycle>'" 'Cyclic table guard missing.'
Assert-Contains "return '<max_depth>'" 'Max-depth guard missing.'
Assert-Contains 'MAX_TABLE_KEYS' 'Table size limit missing.'
Assert-Contains 'MAX_STRING_LENGTH' 'String size limit missing.'
Assert-Contains 'MAX_ENCODED_CONTEXT_LENGTH' 'Encoded payload size limit missing.'
Assert-Contains 'sanitized.__truncated = true' 'Table truncation marker missing.'
Assert-Contains '__truncated = true' 'Payload truncation marker missing.'

Assert-Contains 'local function mergeContext' 'Context merge helper missing.'
Assert-Contains 'makeContextLogger(mergeContext(baseContext, context))' 'Nested context merge missing.'
Assert-Contains 'loggerState.adapters' 'Adapter registry missing.'
Assert-Contains 'function Nexa.Logger.RegisterAdapter' 'RegisterAdapter missing.'
Assert-Contains 'function Nexa.Logger.RemoveAdapter' 'RemoveAdapter missing.'
Assert-Contains 'pcall(adapter.write, entry)' 'Adapter isolation missing.'
Assert-Contains "name ~= 'console'" 'Adapter failure fallback guard missing.'
Assert-Contains 'adapter.categories' 'Adapter category filtering missing.'
Assert-Contains 'adapter.level' 'Adapter level filtering missing.'
Assert-Contains 'UNKNOWN_LEVEL' 'Unknown level handling missing.'
Assert-Contains 'DEFAULT_LOG_LEVEL = Nexa.Config and Nexa.Config.debug and' 'Debug default configuration missing.'
Assert-Contains 'if not isLevelEnabled(level) then' 'Disabled debug/global level guard missing.'

Write-Host 'Core logger validation passed.'
