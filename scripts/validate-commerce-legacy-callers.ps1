$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$legacyMarkers = @('SetShopEnabled','DeleteShop','ListShopItems','UpdateShopItem','RemoveShopItem')
$files = Get-ChildItem -LiteralPath $root -Recurse -File -Include *.lua,*.js,*.ts,*.md,*.ps1 |
    Where-Object {
        $_.FullName -notmatch '\\\.git\\' -and
        $_.FullName -notmatch '\\\[nexa-gameplay\]\\nexa_shops\\' -and
        $_.FullName -notmatch '\\scripts\\validate-commerce-legacy-callers\.ps1$' -and
        $_.FullName -notmatch '\\docs\\architecture\\commerce-legacy-caller-review\.md$'
    }
$hits = @()
foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($marker in $legacyMarkers) {
        if ($content -match [regex]::Escape($marker)) {
            $hits += "$($file.FullName): $marker"
        }
    }
}
if ($hits.Count -gt 0) {
    Write-Host 'validate-commerce-legacy-callers: legacy markers found'
    $hits | ForEach-Object { Write-Host $_ }
} else {
    Write-Host 'validate-commerce-legacy-callers: OK'
}
