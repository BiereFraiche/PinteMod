param(
    [string]$ServerAddress = "",
    [int]$ServerPort = 0,
    [string]$RemoteDataRoot = "",
    [switch]$ResetConfig
)

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'PinteMod v2.1.1 - Remote Control Launcher'

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Save-RconSecret {
    param([string]$Path)
    $parent = Split-Path -Parent $Path
    if ($parent) { Ensure-Directory $parent }
    Write-Host ''
    Write-Host 'First launch: enter the BOIII RCON password.' -ForegroundColor Cyan
    Write-Host 'It stays encrypted on this PC and is never written to the config JSON.' -ForegroundColor DarkGray
    $secure = Read-Host 'RCON password' -AsSecureString
    if ($secure.Length -le 0) { throw 'Empty RCON password.' }
    $encrypted = $secure | ConvertFrom-SecureString
    Write-Utf8NoBom -Path $Path -Content $encrypted
}

function Read-Config {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Invalid local remote-control config: $Path" }
}

function Start-Tool {
    param([string]$ScriptPath, [string[]]$Arguments)
    $args = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $ScriptPath + '"')) + $Arguments
    return Start-Process -FilePath 'powershell.exe' -ArgumentList $args -PassThru
}

$configPath = Join-Path $PSScriptRoot 'PinteMod_Remote_Control.local.json'
$runtime = Join-Path $PSScriptRoot 'runtime'
$secretPath = Join-Path $runtime 'PinteMod_Remote_RCON.secret.txt'
Ensure-Directory $runtime

if ($ResetConfig) {
    Remove-Item -LiteralPath $configPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $secretPath -Force -ErrorAction SilentlyContinue
}

$config = Read-Config -Path $configPath
if ($config) {
    if ([string]::IsNullOrWhiteSpace($ServerAddress)) { $ServerAddress = [string]$config.server_address }
    if ($ServerPort -le 0) { $ServerPort = [int]$config.server_port }
    if ([string]::IsNullOrWhiteSpace($RemoteDataRoot)) { $RemoteDataRoot = [string]$config.remote_data_root }
}

Clear-Host
Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host ' PinteMod v2.1.1 - Remote Control Setup' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host 'This PC will only CONTROL the laptop server.' -ForegroundColor Gray
Write-Host ''

if ([string]::IsNullOrWhiteSpace($ServerAddress)) {
    $ServerAddress = Read-Host '1/3  Laptop LAN IP (example: 192.168.1.90)'
}
if ($ServerPort -le 0) {
    $portText = Read-Host '2/3  BOIII port (your current server uses 27018)'
    if ([string]::IsNullOrWhiteSpace($portText)) { $ServerPort = 27018 }
    else { $ServerPort = [int]$portText }
}
if ([string]::IsNullOrWhiteSpace($RemoteDataRoot)) {
    $RemoteDataRoot = Read-Host '3/3  Shared PinteMod folder (example: \\LAPTOP\PinteModData)'
}

if ([string]::IsNullOrWhiteSpace($ServerAddress)) { throw 'Laptop IP is required.' }
if ($ServerPort -le 0 -or $ServerPort -gt 65535) { throw 'Invalid BOIII port.' }
if ([string]::IsNullOrWhiteSpace($RemoteDataRoot)) { throw 'Shared PinteMod folder is required.' }
if (-not (Test-Path -LiteralPath $RemoteDataRoot)) {
    throw "Cannot open the shared folder: $RemoteDataRoot"
}
if (-not (Test-Path -LiteralPath (Join-Path $RemoteDataRoot 'logs'))) {
    throw "The shared folder does not contain PinteMod logs: $RemoteDataRoot"
}

$save = [ordered]@{
    schema_version = 1
    server_address = $ServerAddress
    server_port = $ServerPort
    remote_data_root = $RemoteDataRoot
}
Write-Utf8NoBom -Path $configPath -Content ($save | ConvertTo-Json -Depth 3)

if (-not (Test-Path -LiteralPath $secretPath)) {
    Save-RconSecret -Path $secretPath
}

$live = Join-Path $PSScriptRoot 'PinteMod_LiveConsole.ps1'
$rcon = Join-Path $PSScriptRoot 'PinteMod_Remote_RCON.ps1'
if (-not (Test-Path -LiteralPath $live)) { throw "Missing file: $live" }
if (-not (Test-Path -LiteralPath $rcon)) { throw "Missing file: $rcon" }

Write-Host ''
Write-Host '[OK] Configuration saved on this PC.' -ForegroundColor Green
Write-Host ("     Server : {0}:{1}" -f $ServerAddress, $ServerPort) -ForegroundColor Gray
Write-Host ("     Logs   : {0}" -f $RemoteDataRoot) -ForegroundColor Gray
Write-Host ''
Write-Host 'Opening two windows:' -ForegroundColor Cyan
Write-Host '  1. PinteMod Live Console = readable monitoring' -ForegroundColor Gray
Write-Host '  2. PinteMod Remote RCON = type server commands' -ForegroundColor Gray

Start-Tool -ScriptPath $live -Arguments @('-RemoteDataRoot', ('"' + $RemoteDataRoot + '"')) | Out-Null
Start-Sleep -Milliseconds 500
Start-Tool -ScriptPath $rcon -Arguments @(
    '-ServerAddress', $ServerAddress,
    '-ServerPort', [string]$ServerPort,
    '-SecretPath', ('"' + $secretPath + '"')
) | Out-Null

Write-Host ''
Write-Host '[DONE] You can close this launcher window.' -ForegroundColor Green
Start-Sleep -Seconds 3
