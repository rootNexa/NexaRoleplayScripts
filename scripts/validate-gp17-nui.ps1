$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
foreach ($resource in @('[nexa-ui]\nexa_banking_ui','[nexa-ui]\nexa_dispatch_ui','[nexa-ui]\nexa_mdt_ui','[nexa-ui]\nexa_phone')) {
    $path = Join-Path $root $resource
    foreach ($file in @('web\index.html','web\style.css','web\app.js')) {
        if (-not (Test-Path -LiteralPath (Join-Path $path $file))) { throw "Missing NUI file $resource\$file" }
    }
}
Write-Host 'validate-gp17-nui: OK'
