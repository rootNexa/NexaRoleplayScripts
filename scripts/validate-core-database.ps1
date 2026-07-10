$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$databasePath = Join-Path $repoRoot '[nexa-core]\nexa-core\server\database.lua'
$configPath = Join-Path $repoRoot '[nexa-core]\nexa-core\shared\config.lua'
$bootstrapPath = Join-Path $repoRoot '[nexa-core]\nexa-core\server\bootstrap.lua'
$database = Get-Content -LiteralPath $databasePath -Raw
$config = Get-Content -LiteralPath $configPath -Raw
$bootstrap = Get-Content -LiteralPath $bootstrapPath -Raw

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

foreach ($api in @('Query', 'Single', 'Scalar', 'Insert', 'Update', 'Delete', 'Transaction', 'IsReady', 'GetHealth')) {
    Assert-Contains $database "function Nexa.Database.$api" "Database API missing: $api"
}

Assert-Contains $database 'validateParams' 'Parameter validation missing.'
Assert-Contains $database 'normalizeSql' 'SQL validation missing.'
Assert-Contains $database 'validateIdentifiers' 'Identifier whitelist validation missing.'
Assert-Contains $database 'identifierWhitelist' 'Identifier whitelist option missing.'
Assert-Contains $database 'ERROR_CODES' 'Database error code table missing.'
Assert-Contains $database 'makeError' 'Uniform error object helper missing.'
Assert-Contains $database 'DB_TIMEOUT' 'Timeout error missing.'
Assert-Contains $database 'SetTimeout(timeoutMs' 'Query timeout handling missing.'
Assert-Contains $database 'database.slow_query' 'Slow query logging missing.'
Assert-Contains $database 'isRetryableError' 'Retry classification missing.'
Assert-Contains $database 'database.retry.maxAttempts' 'Retry config usage missing.'
Assert-Contains $database 'database.retry.delayMs' 'Retry delay config usage missing.'
Assert-Contains $database 'MySQL.transaction' 'Transaction support missing.'
Assert-Contains $database 'Datenbanktransaktion wurde zurueckgerollt.' 'Rollback error handling missing.'
Assert-Contains $database 'Nexa.Database.ready' 'Readiness state missing.'
Assert-Contains $database 'Nexa.Database.health' 'Health state missing.'
Assert-Contains $database 'nexa_core_migrations' 'Migration table missing.'
Assert-Contains $database 'RegisterMigration' 'Migration registration missing.'
Assert-Contains $database 'RunMigrations' 'Migration runner missing.'
Assert-Contains $database 'checksum' 'Migration checksum missing.'
Assert-Contains $database 'DB_MIGRATION_CHECKSUM_MISMATCH' 'Checksum mismatch error missing.'
Assert-Contains $database 'CREATE TABLE IF NOT EXISTS nexa_players' 'Foundation migration missing nexa_players.'
Assert-Contains $database 'CREATE TABLE IF NOT EXISTS nexa_characters' 'Foundation migration missing nexa_characters.'
Assert-Contains $database 'CREATE TABLE IF NOT EXISTS nexa_permissions' 'Foundation migration missing nexa_permissions.'
Assert-Contains $database 'CREATE TABLE IF NOT EXISTS nexa_audit_log' 'Foundation migration missing nexa_audit_log.'
Assert-Contains $bootstrap 'Nexa.Database.RunMigrations()' 'Bootstrap does not run migrations.'
Assert-Contains $config 'database = {' 'Database config section missing.'
Assert-Contains $config 'timeoutMs = getConvarInt(' 'Database timeout convar missing.'
Assert-Contains $config 'slowQueryMs = getConvarInt(' 'Slow query convar missing.'
Assert-Contains $config 'dbRetryMaxAttempts' 'Retry max attempts convar missing.'
Assert-Contains $config 'dbRetryDelayMs' 'Retry delay convar missing.'

Write-Host 'Core database validation passed.'
