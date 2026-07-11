$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$nexaUi = Join-Path $root '[nexa-ui]\nexa_ui'
$adminUi = Join-Path $root '[nexa-admin]\nexa_admin_ui'

$exports = @(
    "exports('registerWindow', registerWindow)",
    "exports('openWindow', openWindow)",
    "exports('closeWindow', closeWindow)",
    "exports('getOpenWindows', getOpenWindows)",
    "exports('showLoading', showLoading)",
    "exports('hideLoading', hideLoading)",
    "exports('showError', showError)",
    "exports('hideError', hideError)"
)

$mainLua = Get-Content -LiteralPath (Join-Path $nexaUi 'client\main.lua') -Raw
foreach ($export in $exports) {
    if ($mainLua -notlike "*$export*") {
        throw "Missing nexa_ui export: $export"
    }
}

$appJs = Get-Content -LiteralPath (Join-Path $nexaUi 'web\app.js') -Raw
$messages = @('ui:windowOpen', 'ui:windowClose', 'ui:loadingOpen', 'ui:loadingClose', 'ui:errorOpen', 'ui:errorClose')
foreach ($message in $messages) {
    if ($appJs -notlike "*$message*") {
        throw "Missing nexa_ui NUI message handler: $message"
    }
}

$adminFiles = @(
    'fxmanifest.lua',
    'client\main.lua',
    'client\nui.lua',
    'web\index.html',
    'web\app.js',
    'web\style.css'
)

foreach ($file in $adminFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $adminUi $file))) {
        throw "Missing nexa_admin_ui file: $file"
    }
}

Write-Host 'GP18 UI validation passed.'
