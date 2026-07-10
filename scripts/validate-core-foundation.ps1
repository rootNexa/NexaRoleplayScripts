$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$coreRoot = Join-Path $repoRoot '[nexa-core]\nexa-core'

function Invoke-CoreValidation {
    param([string] $ScriptName)

    $scriptPath = Join-Path $PSScriptRoot $ScriptName

    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "FAIL: Missing validation script: $ScriptName"
    }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath

    if ($LASTEXITCODE -ne 0) {
        throw "FAIL: Validation failed: $ScriptName"
    }
}

function Assert-NoMatch {
    param(
        [string] $Pattern,
        [string] $Message,
        [string[]] $Allowed = @()
    )

    $matches = @(rg -n $Pattern $coreRoot 2>$null)

    foreach ($line in $matches) {
        $isAllowed = $false

        foreach ($allowedPattern in $Allowed) {
            if ($line -match $allowedPattern) {
                $isAllowed = $true
                break
            }
        }

        if (-not $isAllowed) {
            throw "FAIL: $Message`n$line"
        }
    }
}

Invoke-CoreValidation 'validate-core-lifecycle.ps1'
Invoke-CoreValidation 'validate-core-logger.ps1'
Invoke-CoreValidation 'validate-core-config.ps1'
Invoke-CoreValidation 'validate-core-database.ps1'
Invoke-CoreValidation 'validate-core-eventbus.ps1'
Invoke-CoreValidation 'validate-core-callbacks.ps1'
Invoke-CoreValidation 'validate-core-modules.ps1'
Invoke-CoreValidation 'validate-core-permissions.ps1'
Invoke-CoreValidation 'validate-core-sessions.ps1'
Invoke-CoreValidation 'validate-core-cache.ps1'

Assert-NoMatch 'QBCore|qb-core|qbcore|qbx|Qbox|es_extended|ESX|ox_lib|lib\.' 'Forbidden framework or ox_lib reference found in nexa-core.' @(
    'README.md:',
    'docs\\API.md:'
)
Assert-NoMatch 'TODO|FIXME|PLACEHOLDER|XXX' 'Unresolved marker found in nexa-core.'
Assert-NoMatch 'while true|Wait\(0\)' 'Potential uncontrolled loop found in nexa-core.' @(
    'server\\main.lua:11:',
    'server\\main.lua:51:'
)
Assert-NoMatch 'print\(' 'Unstructured print found in nexa-core.' @(
    'shared\\init.lua:362:',
    'docs\\API.md:'
)
Assert-NoMatch 'GetPlayerToken|hardware|hwid' 'Unsupported hardware identifier logic found in nexa-core.'

Write-Host 'Core foundation validation passed.'
