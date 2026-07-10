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
$cache = Read-RepoFile '[nexa-core]\nexa-core\server\cache.lua'
$bootstrap = Read-RepoFile '[nexa-core]\nexa-core\server\bootstrap.lua'
$api = Read-RepoFile '[nexa-core]\nexa-core\docs\API.md'
$docs = Read-RepoFile 'docs\architecture\core-cache.md'
$overview = Read-RepoFile 'docs\architecture\core-overview.md'

Assert-Regex $manifest "'server/database.lua'[\s\S]*'server/cache.lua'[\s\S]*'server/permissions.lua'" 'cache.lua must load after database and before permission consumers.'

Assert-Contains $cache 'Nexa.Cache = Nexa.Cache or {' 'Nexa.Cache state missing.'
Assert-Contains $cache 'namespaces = {}' 'Namespace store missing.'
Assert-Contains $cache 'loading = {}' 'GetOrLoad loading registry missing.'
Assert-Contains $cache 'cleanupIntervalMs = 60000' 'Automatic cleanup interval missing.'

foreach ($apiName in @('Set', 'Get', 'Has', 'Delete', 'Clear', 'GetOrLoad', 'GetStats', 'Cleanup')) {
    Assert-Contains $cache "function Nexa.Cache.$apiName" "Cache API missing: $apiName"
}

Assert-Contains $cache 'normalizeNamespace' 'Namespace validation missing.'
Assert-Contains $cache 'normalizeKey' 'Key validation missing.'
Assert-Contains $cache 'ttlMs' 'TTL option missing.'
Assert-Contains $cache 'expiresAt' 'Expiration timestamp missing.'
Assert-Contains $cache 'isExpired' 'Expiration check missing.'
Assert-Contains $cache "deleteEntry(state, key, 'expired')" 'Expired entry cleanup missing.'
Assert-Contains $cache 'Cache.Delete(namespace, key)' 'Delete implementation missing.'
Assert-Contains $cache 'Cache.Clear(namespace)' 'Clear implementation missing.'
Assert-Contains $cache 'Cache.GetOrLoad(namespace, key, loader, options)' 'GetOrLoad implementation missing.'
Assert-Contains $cache 'Citizen.Await(pending)' 'Stampede wait missing.'
Assert-Contains $cache 'LOAD_IN_PROGRESS' 'Non-await stampede guard missing.'
Assert-Contains $cache 'pcall(loader' 'Loader error isolation missing.'
Assert-Contains $cache 'loadErrors' 'Loader error stats missing.'
Assert-Contains $cache 'Nexa.Cache.Set(namespace, key, loadedValue, options)' 'GetOrLoad does not cache successful load.'
Assert-Regex $cache 'if\s+not\s+ok\s+or\s+loadErr\s+~= nil[\s\S]*loadErrors' 'Loader failures are not handled before caching.'
Assert-Contains $cache 'maxEntries' 'Maximum entry count missing.'
Assert-Contains $cache 'maxValueBytes' 'Maximum value size missing.'
Assert-Contains $cache 'VALUE_TOO_LARGE' 'Value size limit missing.'
Assert-Contains $cache 'enforceLimit(state)' 'Entry limit enforcement missing.'
Assert-Contains $cache 'evictions' 'Eviction stats missing.'
Assert-Contains $cache 'hits' 'Hit stats missing.'
Assert-Contains $cache 'misses' 'Miss stats missing.'
Assert-Contains $cache 'sets' 'Set stats missing.'
Assert-Contains $cache 'cloneValue' 'Mutation protection missing.'
Assert-Contains $cache 'INVALID_VALUE_TYPE' 'Non-serializable value guard missing.'
Assert-Contains $cache 'SECRET_CACHE_BLOCKED' 'Secret cache guard missing.'
Assert-Contains $cache 'Nexa.Cache.Start()' 'Controlled cache start missing.'
Assert-Contains $cache 'Nexa.Cache.Stop()' 'Controlled cache stop missing.'
Assert-Contains $cache 'Nexa.Cache.running = false' 'Controlled stop flag missing.'

Assert-Contains $bootstrap 'Nexa.Cache.Start()' 'Bootstrap does not start cache cleanup.'
Assert-Contains $bootstrap 'Nexa.Cache.Stop()' 'Bootstrap does not stop cache cleanup.'
Assert-Contains $api 'Nexa.Cache.GetOrLoad(namespace, key, loader, options)' 'API docs missing cache API.'
Assert-Contains $overview 'core-cache.md' 'Core overview does not link cache docs.'
Assert-Contains $docs 'Ungeeignete Cache-Daten' 'Cache docs missing unsuitable data section.'
Assert-Contains $docs 'TTL-Regeln' 'Cache docs missing TTL rules.'
Assert-Contains $docs 'Get-or-Load und Stampede-Schutz' 'Cache docs missing stampede section.'

Write-Host 'Core cache validation passed.'
