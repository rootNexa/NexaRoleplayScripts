param(
    [string]$Suite = 'all',
    [string]$ReportPath = ''
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Script:Findings = New-Object System.Collections.Generic.List[object]
$Script:Skipped = New-Object System.Collections.Generic.List[object]

$TextExtensions = @(
    '.lua', '.js', '.jsx', '.ts', '.tsx', '.html', '.css', '.scss', '.json',
    '.sql', '.cfg', '.ini', '.env', '.yml', '.yaml', '.xml', '.toml', '.ps1',
    '.bat', '.cmd', '.sh', '.md', '.txt', '.lock'
)

$IgnoredDirectories = @(
    '/.git/', '/node_modules/', '/dist/', '/build/', '/.next/', '/coverage/',
    '/vendor/', '/.agents/', '/.codex/'
)

function Convert-ToRepoPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path.Substring($RepoRoot.Length + 1).Replace('\', '/')
    }
    return $Path.Replace('\', '/')
}

function Test-IgnoredPath {
    param([string]$Path)
    $relative = '/' + (Convert-ToRepoPath $Path)
    foreach ($ignored in $IgnoredDirectories) {
        if ($relative.Contains($ignored)) {
            return $true
        }
    }
    return $false
}

function Get-AuditFiles {
    $relativeFiles = & rg --files --hidden -g '!.git/**' -g '!**/node_modules/**' -g '!**/dist/**' -g '!**/build/**' -g '!**/.next/**' -g '!**/coverage/**' -g '!**/vendor/**' -g '!.agents/**' -g '!.codex/**'
    foreach ($relative in $relativeFiles) {
        $fullPath = Join-Path $RepoRoot $relative
        if (-not (Test-Path -LiteralPath $fullPath)) { continue }
        $file = Get-Item -LiteralPath $fullPath
        if ($TextExtensions -notcontains $file.Extension.ToLowerInvariant()) {
            $Script:Skipped.Add([pscustomobject]@{
                Path = Convert-ToRepoPath $file.FullName
                Reason = 'binary-or-unsupported-extension'
            }) | Out-Null
            continue
        }

        $file
    }
}

function Add-Finding {
    param(
        [string]$Suite,
        [string]$Severity,
        [string]$Rule,
        [string]$Path,
        [int]$Line = 0,
        [string]$Message,
        [string]$Evidence = ''
    )

    $Script:Findings.Add([pscustomobject]@{
        Suite = $Suite
        Severity = $Severity
        Rule = $Rule
        Path = $Path
        Line = $Line
        Message = $Message
        Evidence = if ($Evidence.Length -gt 180) { $Evidence.Substring(0, 180) + '...' } else { $Evidence }
    }) | Out-Null
}

function Get-ResourceMap {
    $map = @{}
    $manifests = & rg --files --hidden -g 'fxmanifest.lua' -g '!.git/**' -g '!**/node_modules/**' -g '!**/dist/**' -g '!**/build/**' -g '!.agents/**' -g '!.codex/**'
    foreach ($manifest in $manifests) {
        $fullPath = Join-Path $RepoRoot $manifest
        if (-not (Test-Path -LiteralPath $fullPath)) { continue }
        $resourceName = Split-Path -Leaf (Split-Path -Parent $fullPath)
        $map[$resourceName] = $fullPath
    }
    return $map
}

function Get-ManifestReferences {
    param([string]$ManifestPath)
    $content = Get-Content -LiteralPath $ManifestPath -Raw
    $matches = [regex]::Matches($content, "['""]([^'""]+\.(lua|js|html|css|json|sql|png|jpg|jpeg|svg|webp|ttf|woff|woff2))['""]")
    $refs = New-Object System.Collections.Generic.List[string]
    foreach ($match in $matches) {
        $value = $match.Groups[1].Value
        if ($value.StartsWith('@')) { continue }
        $refs.Add($value) | Out-Null
    }
    return $refs
}

function Invoke-ManifestAudit {
    $resourceMap = Get-ResourceMap
    $allowedExternal = @('oxmysql', 'spawnmanager', 'mapmanager', 'chat', 'sessionmanager', 'hardcap', 'yarn', 'webpack')

    foreach ($manifest in $resourceMap.Values) {
        $relative = Convert-ToRepoPath $manifest
        $dir = Split-Path -Parent $manifest
        $content = Get-Content -LiteralPath $manifest -Raw

        foreach ($required in @('fx_version', 'game')) {
            if ($content -notmatch "(?m)^\s*$required\s+") {
                Add-Finding manifest MEDIUM "manifest.$required.missing" $relative 1 "Manifest is missing $required."
            }
        }

        foreach ($ref in Get-ManifestReferences $manifest) {
            $resolved = Join-Path $dir $ref
            if (-not (Test-Path -LiteralPath $resolved)) {
                Add-Finding manifest HIGH 'manifest.file.missing' $relative 1 "Manifest references missing file." $ref
            }
        }

        $deps = [regex]::Matches($content, "dependency\s+['""]([^'""]+)['""]|dependencies\s*\{(?<block>[\s\S]*?)\}") 
        foreach ($depMatch in $deps) {
            if ($depMatch.Groups[1].Success) {
                $dep = $depMatch.Groups[1].Value
                if (-not $dep.StartsWith('/') -and -not $resourceMap.ContainsKey($dep) -and $allowedExternal -notcontains $dep) {
                    Add-Finding manifest MEDIUM 'manifest.dependency.missing' $relative 1 "Dependency does not exist in repository and is not allowlisted." $dep
                }
            }
            if ($depMatch.Groups['block'].Success) {
                foreach ($inner in [regex]::Matches($depMatch.Groups['block'].Value, "['""]([^'""]+)['""]")) {
                    $dep = $inner.Groups[1].Value
                    if (-not $dep.StartsWith('/') -and -not $resourceMap.ContainsKey($dep) -and $allowedExternal -notcontains $dep) {
                        Add-Finding manifest MEDIUM 'manifest.dependency.missing' $relative 1 "Dependency does not exist in repository and is not allowlisted." $dep
                    }
                }
            }
        }
    }
}

function Invoke-SyntaxAudit {
    $node = Get-Command node -ErrorAction SilentlyContinue
    $lua = Get-Command luac -ErrorAction SilentlyContinue
    if (-not $lua) { $lua = Get-Command lua -ErrorAction SilentlyContinue }

    foreach ($file in Get-AuditFiles) {
        $path = Convert-ToRepoPath $file.FullName
        $ext = $file.Extension.ToLowerInvariant()
        try {
            if ($ext -eq '.json') {
                Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json | Out-Null
            } elseif ($ext -in @('.js', '.jsx') -and $node) {
                & node --check $file.FullName | Out-Null
                if ($LASTEXITCODE -ne 0) { Add-Finding syntax HIGH 'js.parse' $path 1 'node --check failed.' }
            } elseif ($ext -eq '.ps1') {
                $tokens = $null
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
                foreach ($err in $errors) { Add-Finding syntax HIGH 'ps1.parse' $path $err.Extent.StartLineNumber $err.Message }
            } elseif ($ext -eq '.xml') {
                [xml](Get-Content -LiteralPath $file.FullName -Raw) | Out-Null
            } elseif ($ext -eq '.lua') {
                if ($lua) {
                    if ($lua.Name -eq 'luac') { & $lua.Source -p $file.FullName | Out-Null } else { & $lua.Source -e "assert(loadfile(arg[1]))" $file.FullName | Out-Null }
                    if ($LASTEXITCODE -ne 0) { Add-Finding syntax HIGH 'lua.parse' $path 1 'Lua parser failed.' }
                } else {
                    $content = Get-Content -LiteralPath $file.FullName -Raw
                    $openFunctions = ([regex]::Matches($content, '\bfunction\b')).Count
                    $ends = ([regex]::Matches($content, '\bend\b')).Count
                    if ($openFunctions -gt ($ends + 10)) {
                        Add-Finding syntax MEDIUM 'lua.static.balance' $path 1 'Lua parser unavailable; static block balance looks suspicious.'
                    }
                }
            }
        } catch {
            Add-Finding syntax HIGH "$ext.parse" $path 1 $_.Exception.Message
        }
    }

    if (-not $lua) {
        Add-Finding syntax MEDIUM 'lua.parser.unavailable' 'repository' 0 'No lua or luac executable was available; Lua parse checks used static heuristics only.'
    }
}

function Invoke-ExportAudit {
    $defined = @{}
    foreach ($file in Get-AuditFiles | Where-Object { $_.Extension -eq '.lua' }) {
        $path = Convert-ToRepoPath $file.FullName
        $resource = ($path -split '/')[1]
        $lines = Get-Content -LiteralPath $file.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            foreach ($m in [regex]::Matches($lines[$i], "exports\s*\(\s*['""]([^'""]+)['""]")) {
                $key = "${resource}:$($m.Groups[1].Value)"
                $defined[$key] = $path
            }
            foreach ($m in [regex]::Matches($lines[$i], "['""]([^'""]+)['""]\s*,?\s*")) {
                if ($lines[$i] -match 'server_exports|client_exports|exports\s*\{') {
                    $key = "${resource}:$($m.Groups[1].Value)"
                    $defined[$key] = $path
                }
            }
        }
    }

    foreach ($file in Get-AuditFiles | Where-Object { $_.Extension -in @('.lua', '.js') }) {
        $path = Convert-ToRepoPath $file.FullName
        $lines = Get-Content -LiteralPath $file.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            foreach ($m in [regex]::Matches($lines[$i], "exports(?:\[['""]([^'""]+)['""]\]|\.([A-Za-z0-9_\-]+))\s*:\s*([A-Za-z0-9_]+)")) {
                $res = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
                $fn = $m.Groups[3].Value
                if ($res -notmatch '^nexa' -and $res -ne 'oxmysql') { continue }
                $key = "${res}:$fn"
                if (-not $defined.ContainsKey($key) -and $res -ne 'oxmysql') {
                    Add-Finding exports MEDIUM 'export.undefined.static' $path ($i + 1) 'Export call could not be matched to a local definition.' "${res}:$fn"
                }
                if ($lines[$i] -match 'force|skipValidation|trusted|admin') {
                    Add-Finding exports MEDIUM 'export.bypass.parameter' $path ($i + 1) 'Export call contains bypass-like parameter naming; review actor and permission checks.' $lines[$i].Trim()
                }
            }
        }
    }
}

function Invoke-EventAudit {
    foreach ($file in Get-AuditFiles | Where-Object { $_.Extension -eq '.lua' }) {
        $path = Convert-ToRepoPath $file.FullName
        $lines = Get-Content -LiteralPath $file.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match 'RegisterNetEvent|RegisterNUICallback') {
                $window = ($lines[$i..([Math]::Min($lines.Count - 1, $i + 25))] -join "`n")
                if ($window -notmatch 'permission|Permissions|RateLimit|Validate|schema|source|session|actor') {
                    Add-Finding events MEDIUM 'event.validation.context.missing' $path ($i + 1) 'Network or NUI callback lacks nearby validation/actor/rate-limit markers.' $line.Trim()
                }
            }
            if ($line -match 'TriggerServerEvent\(.*(amount|price|item|reward|success|quality|permission|rank|vehicle|property|inventory)') {
                Add-Finding events MEDIUM 'client.server.sensitive.payload' $path ($i + 1) 'Client sends sensitive domain data to server; verify server-side authority.' $line.Trim()
            }
        }
    }
}

function Invoke-ClientTrustAudit {
    foreach ($file in Get-AuditFiles | Where-Object { $_.Extension -eq '.lua' -and $_.FullName -match '\\server\\' }) {
        $path = Convert-ToRepoPath $file.FullName
        $lines = Get-Content -LiteralPath $file.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match 'payload\.(source|character_id|account_id|permission|role|is_admin|amount|price|item_name|vehicle_id|property_id|organization_id|rank|success|quality|plate|vin)') {
                $window = ($lines[[Math]::Max(0, $i - 8)..[Math]::Min($lines.Count - 1, $i + 8)] -join "`n")
                if ($window -notmatch 'Validate|Permissions|Sessions|GetBySource|tonumber|type\(|server') {
                    Add-Finding client_trust HIGH 'payload.trust.unchecked' $path ($i + 1) 'Server appears to consume sensitive payload field without nearby validation markers.' $line.Trim()
                } else {
                    Add-Finding client_trust LOW 'payload.trust.review' $path ($i + 1) 'Sensitive payload field found; review server authority.' $line.Trim()
                }
            }
        }
    }
}

function Invoke-SecretsAudit {
    $patterns = @(
        @{ Name = 'discord.webhook'; Regex = 'https://discord(app)?\.com/api/webhooks/[A-Za-z0-9_\-/]+' },
        @{ Name = 'generic.secret.assignment'; Regex = '(password|passwd|pwd|token|api[_-]?key|secret)\s*[:=]\s*["''][^"'']{8,}["'']' },
        @{ Name = 'private.key'; Regex = '-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----' },
        @{ Name = 'jwt'; Regex = 'eyJ[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{20,}' }
    )
    foreach ($file in Get-AuditFiles) {
        $path = Convert-ToRepoPath $file.FullName
        if ($path -match '^docs/security/') { continue }
        $lines = Get-Content -LiteralPath $file.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            foreach ($pattern in $patterns) {
                if ($lines[$i] -match $pattern.Regex) {
                    $masked = ($Matches[0] -replace '(.{4}).+(.{4})', '$1***$2')
                    Add-Finding secrets HIGH $pattern.Name $path ($i + 1) 'Potential secret or credential found; rotate if real.' $masked
                }
            }
            if ($lines[$i] -match '\b(loadstring|load\s*\(|dofile|PerformHttpRequest)\b') {
                Add-Finding secrets MEDIUM 'dynamic.remote.code.review' $path ($i + 1) 'Dynamic loading or HTTP execution primitive found; review for backdoor risk.' $lines[$i].Trim()
            }
        }
    }
}

function Invoke-SqlAudit {
    foreach ($file in Get-AuditFiles | Where-Object { $_.Extension -in @('.lua', '.sql') }) {
        $path = Convert-ToRepoPath $file.FullName
        $lines = Get-Content -LiteralPath $file.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match 'MySQL\.|exports\.oxmysql|exports\[''oxmysql''\]|exports\["oxmysql"\]') {
                Add-Finding sql LOW 'sql.direct.driver' $path ($i + 1) 'Direct database driver call found; verify this is an approved storage boundary.' $line.Trim()
            }
            if ($line -match '(SELECT|INSERT|UPDATE|DELETE).*(\.\.|format\(|\+)' -and $line -notmatch '\?') {
                Add-Finding sql HIGH 'sql.dynamic.concatenation' $path ($i + 1) 'SQL appears dynamically concatenated without parameter markers.' $line.Trim()
            }
            if ($line -match '\b(DROP|TRUNCATE)\b') {
                Add-Finding sql HIGH 'sql.destructive.migration' $path ($i + 1) 'Destructive SQL keyword found; verify non-production safety and migration intent.' $line.Trim()
            }
        }
    }
}

function Invoke-NuiAudit {
    foreach ($file in Get-AuditFiles | Where-Object { $_.Extension -in @('.js', '.html') }) {
        $path = Convert-ToRepoPath $file.FullName
        $lines = Get-Content -LiteralPath $file.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match 'innerHTML|outerHTML|insertAdjacentHTML') {
                Add-Finding nui HIGH 'nui.html.injection' $path ($i + 1) 'Unsafe HTML sink found.' $line.Trim()
            }
            if ($line -match '\beval\s*\(|new Function') {
                Add-Finding nui CRITICAL 'nui.dynamic.code' $path ($i + 1) 'Dynamic JavaScript execution found.' $line.Trim()
            }
            if ($line -match '<script[^>]+src=["'']https?://') {
                Add-Finding nui MEDIUM 'nui.remote.script' $path ($i + 1) 'Remote script asset found.' $line.Trim()
            }
            if ($line -match 'addEventListener\(["'']message["'']' ) {
                $window = ($lines[$i..([Math]::Min($lines.Count - 1, $i + 15))] -join "`n")
                if ($window -notmatch 'message\.type|event\.data') {
                    Add-Finding nui MEDIUM 'nui.message.validation' $path ($i + 1) 'Message handler lacks nearby type dispatch markers.' $line.Trim()
                }
            }
        }
    }
}

function Invoke-NetworkFileAudit {
    foreach ($file in Get-AuditFiles) {
        $path = Convert-ToRepoPath $file.FullName
        $lines = Get-Content -LiteralPath $file.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match 'PerformHttpRequest|fetch\(|http://|https://') {
                if ($line -match 'localhost|127\.0\.0\.1|169\.254\.169\.254|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.') {
                    Add-Finding network HIGH 'network.ssrf.private.target' $path ($i + 1) 'HTTP target references local/private network range.' $line.Trim()
                } else {
                    Add-Finding network LOW 'network.external.reference' $path ($i + 1) 'External network reference found; verify timeouts and allowlist.' $line.Trim()
                }
            }
            if ($line -match '\.\./|file://|SaveResourceFile|LoadResourceFile') {
                Add-Finding network MEDIUM 'file.path.review' $path ($i + 1) 'File path or resource file primitive found; review traversal controls.' $line.Trim()
            }
        }
    }
}

function Invoke-RestartAudit {
    $manifests = & rg --files --hidden -g 'fxmanifest.lua' -g '!.git/**' -g '!**/node_modules/**' -g '!**/dist/**' -g '!**/build/**' -g '!.agents/**' -g '!.codex/**'
    foreach ($manifestPath in $manifests) {
        $fullManifestPath = Join-Path $RepoRoot $manifestPath
        if (-not (Test-Path -LiteralPath $fullManifestPath)) { continue }
        $dir = Split-Path -Parent $fullManifestPath
        $resource = Split-Path -Leaf $dir
        $luaFiles = Get-ChildItem -LiteralPath $dir -Recurse -Filter '*.lua' -File
        $combined = ($luaFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
        if ($combined -match 'CreateThread|SetTimeout|RegisterNetEvent|CreateVehicle|CreateObject|SetNuiFocus') {
            if ($combined -notmatch 'onResourceStop') {
                Add-Finding restart MEDIUM 'restart.cleanup.missing' "$resource/fxmanifest.lua" 1 'Resource uses runtime state primitives but has no onResourceStop handler.'
            }
        }
        if ($combined -match 'playerDropped' -eq $false -and $combined -match 'Sessions|session|inventory|lock|token') {
            Add-Finding restart LOW 'disconnect.cleanup.review' "$resource/fxmanifest.lua" 1 'Resource references session/lock/token/inventory concepts without playerDropped marker.'
        }
    }
}

function Invoke-DupeAudit {
    foreach ($file in Get-AuditFiles | Where-Object { $_.Extension -eq '.lua' -and $_.FullName -match '\\server\\' }) {
        $path = Convert-ToRepoPath $file.FullName
        $lines = Get-Content -LiteralPath $file.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '\b(AddItem|RemoveItem|MoveItem|Credit|Debit|Transfer|CreateVehicle|SpawnVehicle|Buy|Sell|Reward|PayInvoice|Capture|Release)\b') {
                $window = ($lines[[Math]::Max(0, $i - 12)..[Math]::Min($lines.Count - 1, $i + 12)] -join "`n")
                if ($window -notmatch 'Transaction|lock|Lock|idempot|version|ledger|Validate|atomic') {
                    Add-Finding dupe MEDIUM 'dupe.atomicity.review' $path ($i + 1) 'Economic/item/vehicle/property operation lacks nearby atomicity/idempotency markers.' $line.Trim()
                }
            }
        }
    }
}

function Invoke-PermissionAudit {
    foreach ($file in Get-AuditFiles | Where-Object { $_.Extension -eq '.lua' }) {
        $path = Convert-ToRepoPath $file.FullName
        $lines = Get-Content -LiteralPath $file.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match 'RegisterCommand\(' -and $line -match 'false\)?\s*$') {
                Add-Finding permissions MEDIUM 'command.unrestricted.review' $path ($i + 1) 'Command is registered unrestricted; verify explicit permission checks inside handler.' $line.Trim()
            }
            if ($line -match 'IsPlayerAceAllowed' -and $line -notmatch 'Permissions') {
                Add-Finding permissions LOW 'ace.domain.permission.review' $path ($i + 1) 'ACE check found; verify it is bootstrap/fallback and not sole domain authority.' $line.Trim()
            }
            if ($line -match 'owner|admin|superadmin|god' -and $line -match 'license:|discord:|steam:') {
                Add-Finding permissions HIGH 'hardcoded.admin.identifier' $path ($i + 1) 'Possible hardcoded privileged identifier.' ($line.Trim() -replace '([A-Fa-f0-9]{8})[A-Fa-f0-9]+', '$1***')
            }
        }
    }
}

function Invoke-SelectedAudit {
    switch ($Suite) {
        'syntax' { Invoke-SyntaxAudit }
        'manifests' { Invoke-ManifestAudit }
        'exports' { Invoke-ExportAudit }
        'events' { Invoke-EventAudit }
        'client-trust' { Invoke-ClientTrustAudit }
        'secrets' { Invoke-SecretsAudit }
        'sql' { Invoke-SqlAudit }
        'nui' { Invoke-NuiAudit }
        'restart' { Invoke-RestartAudit }
        'dupe' { Invoke-DupeAudit }
        'permissions' { Invoke-PermissionAudit }
        'network' { Invoke-NetworkFileAudit }
        default {
            Invoke-SyntaxAudit
            Invoke-ManifestAudit
            Invoke-ExportAudit
            Invoke-EventAudit
            Invoke-ClientTrustAudit
            Invoke-PermissionAudit
            Invoke-DupeAudit
            Invoke-SqlAudit
            Invoke-NuiAudit
            Invoke-NetworkFileAudit
            Invoke-SecretsAudit
            Invoke-RestartAudit
        }
    }
}

function Write-AuditOutput {
    $criticalHigh = @($Script:Findings | Where-Object { $_.Severity -in @('CRITICAL', 'HIGH') })
    foreach ($finding in $Script:Findings) {
        $line = "{0} {1}:{2} [{3}] {4} - {5}" -f $finding.Severity, $finding.Path, $finding.Line, $finding.Rule, $finding.Message, $finding.Evidence
        Write-Host $line
    }
    Write-Host ("Full audit suite={0} findings={1} critical_high={2}" -f $Suite, $Script:Findings.Count, $criticalHigh.Count)
    if ($ReportPath -ne '') {
        $json = [pscustomobject]@{
            suite = $Suite
            generated_at = (Get-Date).ToString('s')
            findings = $Script:Findings
            skipped = $Script:Skipped
        } | ConvertTo-Json -Depth 8
        Set-Content -LiteralPath $ReportPath -Value $json -Encoding UTF8
    }
    if ($criticalHigh.Count -gt 0) { exit 1 }
}

Invoke-SelectedAudit
Write-AuditOutput
