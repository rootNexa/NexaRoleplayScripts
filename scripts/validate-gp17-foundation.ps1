$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$resources = @(
    '[nexa-ui]\nexa_phone',
    '[nexa-gameplay]\nexa_radio',
    '[nexa-gameplay]\nexa_documents',
    '[nexa-gameplay]\nexa_banking',
    '[nexa-ui]\nexa_banking_ui',
    '[nexa-ui]\nexa_dispatch_ui',
    '[nexa-ui]\nexa_mdt_ui',
    '[nexa-ui]\nexa_theme',
    '[nexa-ui]\nexa_ui_components'
)
$text = ''
foreach ($resource in $resources) {
    $path = Join-Path $root $resource
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing GP17 resource $resource" }
    $text += Get-ChildItem -LiteralPath $path -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw } | Out-String
}
foreach ($forbidden in @('ox_lib','@ox_lib','ox_inventory','qbcore','qbx','es_extended','lib.')) {
    if ($text -match [regex]::Escape($forbidden)) { throw "Forbidden GP17 marker $forbidden" }
}
foreach ($marker in @('nexa_phone_contacts','nexa_radio_channels','nexa_document_records','nexa_banking_ui','nexa_dispatch_ui','nexa_mdt_ui','NexaThemeTokens','NexaUiComponents')) {
    if ($text -notmatch [regex]::Escape($marker)) { throw "Missing GP17 marker $marker" }
}
Write-Host 'validate-gp17-foundation: OK'
