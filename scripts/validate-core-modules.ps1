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
$modules = Read-RepoFile '[nexa-core]\nexa-core\server\modules.lua'
$bootstrap = Read-RepoFile '[nexa-core]\nexa-core\server\bootstrap.lua'
$api = Read-RepoFile '[nexa-core]\nexa-core\docs\API.md'
$docs = Read-RepoFile 'docs\architecture\core-modules.md'

Assert-Contains $manifest "'server/modules.lua'" 'Module loader is not loaded by fxmanifest.'

Assert-Contains $modules 'Nexa.Modules = Nexa.Modules or {' 'Nexa.Modules state missing.'
Assert-Contains $modules 'function Nexa.Modules.Register(definition)' 'Modules.Register API missing.'
Assert-Contains $modules 'function Nexa.Modules.InitializeAll()' 'Modules.InitializeAll API missing.'
Assert-Contains $modules 'function Nexa.Modules.StartAll()' 'Modules.StartAll API missing.'
Assert-Contains $modules 'function Nexa.Modules.StopAll(reason)' 'Modules.StopAll API missing.'
Assert-Contains $modules 'function Nexa.Modules.Get(name)' 'Modules.Get API missing.'
Assert-Contains $modules 'function Nexa.Modules.GetStatus(name)' 'Modules.GetStatus API missing.'
Assert-Contains $modules 'function Nexa.Modules.GetAllStatuses()' 'Modules.GetAllStatuses API missing.'
Assert-Contains $modules 'function Nexa.Modules.IsReady(name)' 'Modules.IsReady API missing.'
Assert-Contains $modules 'function Nexa.Modules.GetHealth(name)' 'Modules.GetHealth API missing.'

Assert-Contains $modules 'local function buildDependencyGraph()' 'Dependency graph builder missing.'
Assert-Contains $modules 'local function topologicalSort()' 'Topological sort missing.'
Assert-Contains $modules 'MISSING_DEPENDENCY' 'Missing dependency error missing.'
Assert-Contains $modules 'CYCLIC_DEPENDENCY' 'Cycle detection error missing.'
Assert-Contains $modules 'optionalDependencies' 'Optional dependency handling missing.'
Assert-Contains $modules 'DUPLICATE_MODULE' 'Duplicate module guard missing.'
Assert-Contains $modules 'ALREADY_INITIALIZED' 'Double initialization guard missing.'
Assert-Contains $modules 'ALREADY_STARTED' 'Double start guard missing.'
Assert-Contains $modules 'Nexa.Modules.StopAll(' 'Critical failure rollback missing.'
Assert-Contains $modules 'for index = #stopOrder, 1, -1 do' 'Reverse stop order missing.'
Assert-Contains $modules 'pcall(handler, module)' 'Lifecycle error isolation missing.'
Assert-Contains $modules 'pcall(module.Health, module)' 'Health error isolation missing.'
Assert-Contains $modules 'module.critical' 'Critical module behavior missing.'
Assert-Regex $modules 'if\s+not\s+ok\s+then[\s\S]*return failModule\(module, phase, err\)' 'Initialize/Start/Ready failure path missing.'

Assert-Contains $bootstrap 'Nexa.Modules.InitializeAll()' 'Bootstrap does not initialize modules.'
Assert-Contains $bootstrap 'Nexa.Modules.StartAll()' 'Bootstrap does not start modules.'
Assert-Contains $bootstrap 'Nexa.Modules.ReadyAll()' 'Bootstrap does not ready modules.'
Assert-Contains $bootstrap 'Nexa.Modules.StopAll(reason)' 'Bootstrap does not stop modules.'
Assert-Contains $bootstrap 'MODULE_INITIALIZE_FAILED' 'Bootstrap initialize failure handling missing.'
Assert-Contains $bootstrap 'MODULE_START_FAILED' 'Bootstrap start failure handling missing.'
Assert-Contains $bootstrap 'MODULE_READY_FAILED' 'Bootstrap ready failure handling missing.'

Assert-Contains $api 'Nexa.Modules.Register(definition)' 'API documentation for module loader missing.'
Assert-Contains $docs 'Dependency-Regeln' 'Module documentation dependency section missing.'
Assert-Contains $docs 'Fehlerverhalten' 'Module documentation error behavior missing.'
Assert-Contains $docs 'Stop wird die zuletzt gestartete Reihenfolge umgekehrt' 'Module documentation stop order missing.'

Write-Host 'Core modules validation passed.'
