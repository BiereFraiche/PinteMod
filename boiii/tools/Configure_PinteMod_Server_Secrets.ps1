param(
    [string]$ServerRoot = "",
    [int]$ServerPort = 0
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "PinteMod v2.1.1 - Configuration RCON persistante"

function Resolve-ServerRoot {
    param([string]$RequestedRoot)

    function Test-RootCandidate {
        param([string]$Candidate)

        if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }
        try { $full = [System.IO.Path]::GetFullPath($Candidate.Trim('"')) }
        catch { return $null }

        if (Test-Path -LiteralPath (Join-Path $full "boiii")) { return $full }

        if ((Split-Path -Leaf $full) -ieq "boiii") {
            $parent = Split-Path -Parent $full
            if ($parent -and (Test-Path -LiteralPath $full)) {
                return [System.IO.Path]::GetFullPath($parent)
            }
        }

        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        $resolved = Test-RootCandidate -Candidate $RequestedRoot
        if ($resolved) { return $resolved }
        throw "Le dossier fourni ne contient pas boiii : $RequestedRoot"
    }

    foreach ($seed in @($PSScriptRoot, (Get-Location).Path) | Select-Object -Unique) {
        $candidate = $seed
        for ($depth = 0; $depth -lt 6 -and $candidate; $depth++) {
            $resolved = Test-RootCandidate -Candidate $candidate
            if ($resolved) { return $resolved }
            $parent = Split-Path -Parent $candidate
            if (-not $parent -or $parent -eq $candidate) { break }
            $candidate = $parent
        }
    }

    $entered = Read-Host "Dossier qui contient directement boiii"
    $resolved = Test-RootCandidate -Candidate $entered
    if (-not $resolved) { throw "Dossier serveur invalide : $entered" }
    return $resolved
}

function Resolve-ServerPort {
    param(
        [int]$RequestedPort,
        [string]$Root,
        [string]$BridgeConfigPath
    )

    if ($RequestedPort -ge 1 -and $RequestedPort -le 65535) {
        return $RequestedPort
    }

    if (Test-Path -LiteralPath $BridgeConfigPath) {
        try {
            $existing = Get-Content -LiteralPath $BridgeConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
            $existingPort = [int]$existing.server_port
            if ($existingPort -ge 1 -and $existingPort -le 65535) {
                return $existingPort
            }
        }
        catch { }
    }

    foreach ($file in (Get-ChildItem -LiteralPath $Root -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @(".bat", ".cmd") })) {
        try {
            $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
            $match = [regex]::Match($text, '(?im)\bGamePort\s*=\s*"?(?<port>\d{2,5})"?')
            if (-not $match.Success) {
                $match = [regex]::Match($text, '(?im)(?:\+set\s+|\+)?net_port\s+"?(?<port>\d{2,5})"?')
            }
            if ($match.Success) {
                $candidate = [int]$match.Groups['port'].Value
                if ($candidate -ge 1 -and $candidate -le 65535) {
                    return $candidate
                }
            }
        }
        catch { }
    }

    return 27017
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Get-PlainText {
    param([Security.SecureString]$Secure)
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

$root = Resolve-ServerRoot -RequestedRoot $ServerRoot
$zoneRoot = Join-Path $root "zone"
$boiiiRoot = Join-Path $root "boiii"
$toolsRoot = Join-Path $boiiiRoot "tools"
$serverCfg = Join-Path $zoneRoot "server_zm.cfg"
$localSecretsCfg = Join-Path $zoneRoot "pintemod_server_secrets.cfg"
$bridgeSecret = Join-Path $toolsRoot "PinteMod_GeoIP_Bridge.secret.txt"
$bridgeConfig = Join-Path $toolsRoot "PinteMod_GeoIP_Bridge.local.json"
$bridgeExample = Join-Path $toolsRoot "PinteMod_GeoIP_Bridge.example.json"
$resolvedServerPort = Resolve-ServerPort -RequestedPort $ServerPort -Root $root -BridgeConfigPath $bridgeConfig

if (-not (Test-Path -LiteralPath $serverCfg)) {
    throw "Fichier Zombies introuvable : $serverCfg"
}
if (-not (Test-Path -LiteralPath $toolsRoot)) {
    New-Item -ItemType Directory -Path $toolsRoot -Force | Out-Null
}

Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host " PinteMod v2.1.1 - Configuration RCON persistante" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host " Serveur : $root" -ForegroundColor Gray
Write-Host "" 
Write-Host "Le mot de passe sera :" -ForegroundColor Cyan
Write-Host " - ecrit dans zone\pintemod_server_secrets.cfg pour BOIII" -ForegroundColor Gray
Write-Host " - chiffre par Windows DPAPI pour le bridge GeoIP" -ForegroundColor Gray
Write-Host "Il ne sera jamais affiche par cet outil." -ForegroundColor Yellow
Write-Host ""

$secure = Read-Host "Nouveau mot de passe RCON" -AsSecureString
$plain = Get-PlainText -Secure $secure
try {
    if ([string]::IsNullOrWhiteSpace($plain)) { throw "Le mot de passe RCON ne peut pas etre vide." }
    if ($plain.Length -lt 8) { throw "Utilisez au moins 8 caracteres pour le mot de passe RCON." }
    if ($plain -match '[\s"\r\n]') {
        throw "Le mot de passe RCON ne doit contenir ni espace, ni guillemet, ni retour a la ligne."
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backup = "$serverCfg.pintemod_$timestamp.bak"
    Copy-Item -LiteralPath $serverCfg -Destination $backup -Force

    $cfgText = Get-Content -LiteralPath $serverCfg -Raw -ErrorAction Stop
    $cfgText = [regex]::Replace(
        $cfgText,
        '(?ms)^\s*// BEGIN PINTEMOD LOCAL SECRETS\s*$.*?^\s*// END PINTEMOD LOCAL SECRETS\s*$(?:\r?\n)?',
        ''
    )
    $cfgText = [regex]::Replace(
        $cfgText,
        '(?im)^[ \t]*(?:set[ \t]+)?rcon_password\b[^\r\n]*(?:\r?\n)?',
        ''
    )
    $cfgText = [regex]::Replace(
        $cfgText,
        '(?im)^[ \t]*(?:set[ \t]+)?g_password\b[^\r\n]*(?:\r?\n)?',
        ''
    )

    $managedBlock = @"
// BEGIN PINTEMOD LOCAL SECRETS
// Generated locally. Do not publish this file or its contents.
// Loaded LAST so other CFG files cannot overwrite these values afterwards.
exec "pintemod_server_secrets.cfg"
// END PINTEMOD LOCAL SECRETS
"@

    # Append the managed block at the very end. BOIII executes server_zm.cfg
    # from top to bottom, so this guarantees the local RCON secret and the
    # empty join password win over earlier defaults or included CFG files.
    $cfgText = $cfgText.TrimEnd("`r", "`n") + "`r`n`r`n" + $managedBlock + "`r`n"
    Write-Utf8NoBom -Path $serverCfg -Content $cfgText

    $secretCfgText = @"
// PinteMod local server secrets - generated on $timestamp
// Keep this file private and never upload it to GitHub.
set rcon_password "$plain"
set g_password ""
"@
    Write-Utf8NoBom -Path $localSecretsCfg -Content $secretCfgText

    $encrypted = ConvertTo-SecureString -String $plain -AsPlainText -Force | ConvertFrom-SecureString
    Write-Utf8NoBom -Path $bridgeSecret -Content $encrypted

    try {
        if (Test-Path -LiteralPath $bridgeConfig) {
            $config = Get-Content -LiteralPath $bridgeConfig -Raw | ConvertFrom-Json -ErrorAction Stop
        }
        elseif (Test-Path -LiteralPath $bridgeExample) {
            $config = Get-Content -LiteralPath $bridgeExample -Raw | ConvertFrom-Json -ErrorAction Stop
        }
        else {
            throw "Configuration GeoIP exemple introuvable : $bridgeExample"
        }
        $config.server_address = "127.0.0.1"
        $config.server_port = $resolvedServerPort
        $json = $config | ConvertTo-Json -Depth 8
        Write-Utf8NoBom -Path $bridgeConfig -Content $json
    }
    catch {
        Write-Host "[WARN] Configuration GeoIP locale non modifiee : $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Write-Host "" 
    Write-Host "[OK] server_zm.cfg sauvegarde : $backup" -ForegroundColor Green
    Write-Host "[OK] RCON persistant : $localSecretsCfg" -ForegroundColor Green
    Write-Host "[OK] Secret GeoIP DPAPI synchronise : $bridgeSecret" -ForegroundColor Green
    Write-Host "[OK] g_password sera vide au prochain demarrage." -ForegroundColor Green

    # Warn about launch/config files that could still override the managed
    # values after +exec server_zm.cfg. Never print matching lines or secrets.
    $overrideFiles = New-Object System.Collections.Generic.List[string]
    $scanRoots = @($root, $zoneRoot) | Select-Object -Unique
    foreach ($scanRoot in $scanRoots) {
        if (-not (Test-Path -LiteralPath $scanRoot)) { continue }
        foreach ($file in (Get-ChildItem -LiteralPath $scanRoot -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @(".bat", ".cmd", ".cfg") })) {
            if ($file.FullName -in @($serverCfg, $localSecretsCfg)) { continue }
            try {
                $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
                if ($text -match '(?im)\b(?:rcon_password|g_password)\b') {
                    $overrideFiles.Add($file.FullName) | Out-Null
                }
            }
            catch { }
        }
    }
    foreach ($overrideFile in ($overrideFiles | Sort-Object -Unique)) {
        Write-Host "[WARN] Verifier un possible override dans : $overrideFile" -ForegroundColor Yellow
    }
    Write-Host "[OK] Port GeoIP configure : 127.0.0.1:$resolvedServerPort" -ForegroundColor Green
    Write-Host "" 
    Write-Host "Redemarrez completement BOIII puis relancez le bridge." -ForegroundColor Cyan
}
finally {
    $plain = $null
    $secure = $null
}
