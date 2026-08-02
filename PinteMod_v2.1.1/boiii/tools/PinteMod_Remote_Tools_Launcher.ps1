param(
    [string]$ServerRoot = "",
    [string]$ServerAddress = "",
    [int]$ServerPort = 0
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "PinteMod v2.1.1 - Remote Tools"

$mutex = New-Object System.Threading.Mutex($false, "Global\PinteMod_v2_1_RemoteTools")
$mutexOwned = $false
try {
    $mutexOwned = $mutex.WaitOne(0, $false)
}
catch [System.Threading.AbandonedMutexException] {
    $mutexOwned = $true
}
if (-not $mutexOwned) {
    $mutex.Dispose()
    throw "PinteMod remote tools are already being launched."
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Resolve-ServerRoot {
    param([string]$RequestedRoot)

    function Test-Candidate {
        param([string]$Candidate)
        if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }
        try { $full = [System.IO.Path]::GetFullPath($Candidate.Trim('"')) }
        catch { return $null }
        if (Test-Path -LiteralPath (Join-Path $full "boiii")) { return $full }
        if ((Split-Path -Leaf $full) -ieq "boiii") {
            $parent = Split-Path -Parent $full
            if ($parent) { return [System.IO.Path]::GetFullPath($parent) }
        }
        return $null
    }

    $resolved = Test-Candidate $RequestedRoot
    if ($resolved) { return $resolved }

    $entered = Read-Host "Local/UNC folder that directly contains boiii"
    $resolved = Test-Candidate $entered
    if (-not $resolved) { throw "Invalid server folder: $entered" }
    return $resolved
}

function Start-Tool {
    param([string]$ScriptPath, [string[]]$Arguments)
    $args = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $ScriptPath + '"')) + $Arguments
    return Start-Process -FilePath 'powershell.exe' -ArgumentList $args -PassThru
}

$processes = New-Object System.Collections.Generic.List[object]
try {
    $examplePath = Join-Path $PSScriptRoot "PinteMod_Remote_Tools.example.json"
    $localPath = Join-Path $PSScriptRoot "PinteMod_Remote_Tools.local.json"
    if (Test-Path -LiteralPath $localPath) {
        $config = Get-Content -LiteralPath $localPath -Raw | ConvertFrom-Json
    }
    elseif (Test-Path -LiteralPath $examplePath) {
        $config = Get-Content -LiteralPath $examplePath -Raw | ConvertFrom-Json
    }
    else {
        $config = [PSCustomObject]@{ server_root=""; server_address=""; server_port=27017 }
    }

    if ([string]::IsNullOrWhiteSpace($ServerRoot)) { $ServerRoot = [string]$config.server_root }
    if ([string]::IsNullOrWhiteSpace($ServerAddress)) { $ServerAddress = [string]$config.server_address }
    if ($ServerPort -le 0) { $ServerPort = [int]$config.server_port }

    $resolvedRoot = Resolve-ServerRoot -RequestedRoot $ServerRoot
    $toolsRoot = Join-Path $resolvedRoot "boiii\tools"

    $secret = Join-Path $toolsRoot "PinteMod_GeoIP_Bridge.secret.txt"
    if (-not (Test-Path -LiteralPath $secret)) {
        Write-Host "GeoIP RCON secret is not configured for this Windows account/machine." -ForegroundColor Yellow
        & (Join-Path $toolsRoot "Configure_PinteMod_Server_Secrets.ps1") -ServerRoot $resolvedRoot
    }

    if ([string]::IsNullOrWhiteSpace($ServerAddress)) {
        $ServerAddress = Read-Host "BOIII server address (LAN/VPN/public IP; not 127.0.0.1 unless BOIII is local)"
    }
    if ($ServerPort -le 0) {
        $enteredPort = Read-Host "BOIII UDP/RCON port"
        $ServerPort = [int]$enteredPort
    }

    $config.server_root = $resolvedRoot
    $config.server_address = $ServerAddress
    $config.server_port = $ServerPort
    Write-Utf8NoBom -Path $localPath -Content ($config | ConvertTo-Json -Depth 4)

    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host " PinteMod v2.1.1 - Remote Tools" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host " Server files : $resolvedRoot" -ForegroundColor Gray
    Write-Host " RCON target  : $ServerAddress`:$ServerPort" -ForegroundColor Gray
    Write-Host " Security     : use LAN/VPN and restrict firewall access" -ForegroundColor Yellow

    $processes.Add((Start-Tool -ScriptPath (Join-Path $toolsRoot "PinteMod_Ban_Service.ps1") -Arguments @('-ServerRoot', ('"' + $resolvedRoot + '"')))) | Out-Null
    $processes.Add((Start-Tool -ScriptPath (Join-Path $toolsRoot "PinteMod_GeoIP_Bridge.ps1") -Arguments @('-ServerRoot', ('"' + $resolvedRoot + '"'), '-ServerAddress', $ServerAddress, '-ServerPort', [string]$ServerPort))) | Out-Null
    $processes.Add((Start-Tool -ScriptPath (Join-Path $toolsRoot "PinteMod_LiveConsole.ps1") -Arguments @('-ServerRoot', ('"' + $resolvedRoot + '"')))) | Out-Null

    Write-Host "[OK] Ban Service, GeoIP Bridge and Live Console started." -ForegroundColor Green
    Write-Host "Press Ctrl+C in this window to close tools launched here." -ForegroundColor DarkGray
    while ($true) { Start-Sleep -Seconds 2 }
}
finally {
    foreach ($process in $processes) {
        try {
            if ($process -and -not $process.HasExited) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
        }
        catch { }
    }
    if ($mutex) {
        try {
            if ($mutexOwned) { $mutex.ReleaseMutex() | Out-Null }
        }
        catch { }
        $mutex.Dispose()
    }
}
