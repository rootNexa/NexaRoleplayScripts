$ErrorActionPreference = 'Continue'
$validators = @(
    'validate-full-repository-syntax.ps1',
    'validate-full-resource-manifests.ps1',
    'validate-full-export-usage.ps1',
    'validate-full-event-security.ps1',
    'validate-full-client-trust.ps1',
    'validate-full-secrets.ps1',
    'validate-full-sql-security.ps1',
    'validate-full-nui-security.ps1',
    'validate-full-restart-cleanup.ps1',
    'validate-full-dupe-risks.ps1'
)
$failed = @()
foreach ($validator in $validators) {
    Write-Host "== $validator"
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $validator)
    if ($LASTEXITCODE -ne 0) { $failed += $validator }
}
if ($failed.Count -gt 0) {
    Write-Host ("Full security audit validators failed: {0}" -f ($failed -join ', '))
    exit 1
}
Write-Host 'Full security audit validators passed.'
