$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$resources = @(
    '[nexa-core]\nexa_beta',
    '[nexa-admin]\nexa_admin_ui',
    '[nexa-tests]\nexa-beta-runtime-tests'
)

foreach ($resource in $resources) {
    $path = Join-Path $root $resource
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing GP18 resource: $resource"
    }
}

$forbidden = 'ox_lib|@ox_lib|qbcore|qbx|es_extended|ox_inventory'

foreach ($resource in $resources) {
    $path = Join-Path $root $resource
    $matches = Get-ChildItem -LiteralPath $path -Recurse -File | Select-String -Pattern $forbidden -CaseSensitive:$false
    if ($matches) {
        $matches | ForEach-Object { Write-Host $_.Path ':' $_.LineNumber ':' $_.Line }
        throw "Forbidden framework dependency found in $resource"
    }
}

$betaPath = Join-Path $root '[nexa-core]\nexa_beta'
$requiredMarkers = @(
    'RegisterCreator',
    'ListCreators',
    'SetFeatureFlag',
    'GetReadiness',
    'CollectHealth',
    'RecordPerformanceSnapshot',
    'nexa_creator_registries',
    'nexa_feature_flags',
    'nexa_performance_baselines'
)

foreach ($marker in $requiredMarkers) {
    $found = Get-ChildItem -LiteralPath $betaPath -Recurse -File | Select-String -SimpleMatch $marker
    if (-not $found) {
        throw "Missing GP18 marker in nexa_beta: $marker"
    }
}

Write-Host 'GP18 foundation validation passed.'
