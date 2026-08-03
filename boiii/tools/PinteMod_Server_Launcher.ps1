param(
    [string]$PackageRoot = "",
    [string]$ServerRoot = "",
    [string]$ServerLauncher = "",
    [switch]$ServerOnly,
    [switch]$ResetRcon
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "PinteMod v2.1.1"

$mutex = New-Object System.Threading.Mutex($false, "Global\PinteMod_v2_1_ServerLauncher")
$mutexOwned = $false
try {
    $mutexOwned = $mutex.WaitOne(0, $false)
}
catch [System.Threading.AbandonedMutexException] {
    $mutexOwned = $true
}
if (-not $mutexOwned) {
    $mutex.Dispose()
    throw "PinteMod is already being launched by another instance."
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Resolve-PinteModLayout {
    param([string]$RequestedRoot, [string]$RequestedPackageRoot)

    function Test-Candidate {
        param([string]$Candidate)
        if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }
        try { $full = [System.IO.Path]::GetFullPath($Candidate.Trim('"')) }
        catch { return $null }

        $nestedBoiii = Join-Path $full "boiii"
        if ((Test-Path -LiteralPath (Join-Path $nestedBoiii "custom_scripts")) -and
            (Test-Path -LiteralPath (Join-Path $nestedBoiii "tools"))) {
            return [pscustomobject]@{ ServerRoot = $full; BoiiiRoot = $nestedBoiii }
        }

        if ((Split-Path -Leaf $full) -ieq "boiii" -and
            (Test-Path -LiteralPath (Join-Path $full "custom_scripts")) -and
            (Test-Path -LiteralPath (Join-Path $full "tools"))) {
            return [pscustomobject]@{ ServerRoot = (Split-Path -Parent $full); BoiiiRoot = $full }
        }
        return $null
    }

    foreach ($seed in @($RequestedRoot, $RequestedPackageRoot, $PSScriptRoot, (Get-Location).Path) | Select-Object -Unique) {
        $candidate = $seed
        for ($depth = 0; $depth -lt 7 -and $candidate; $depth++) {
            $result = Test-Candidate -Candidate $candidate
            if ($result) { return $result }
            $parent = Split-Path -Parent $candidate
            if (-not $parent -or $parent -eq $candidate) { break }
            $candidate = $parent
        }
    }

    $entered = Read-Host "Folder that directly contains boiii"
    $result = Test-Candidate -Candidate $entered
    if (-not $result) { throw "Invalid server folder: $entered" }
    return $result
}

function Get-LauncherCandidates {
    param([string]$Root)
    $excluded = @(
        "Launch_PinteMod_Server.bat",
        "Launch_PinteMod_GeoIP_Bridge.bat",
        "Launch_PinteMod_LiveConsole.bat",
        "Configure_PinteMod_Server_Secrets.bat",
        "Configure_PinteMod_RCON.bat",
        "Launch_PinteMod_Server_Only.bat",
        "Launch_PinteMod_Remote_Tools.bat",
        "Verify_PinteMod_Installation.bat",
        "Test_PinteMod_v2.1.1.bat"
    )
    $items = Get-ChildItem -LiteralPath $Root -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.bat', '.cmd') -and $_.Name -notin $excluded }

    $preferred = New-Object System.Collections.Generic.List[object]
    foreach ($item in $items) {
        try { $content = Get-Content -LiteralPath $item.FullName -Raw -ErrorAction Stop }
        catch { continue }
        if ($item.Name -match '(?i)(boiii|server|zombies|start|launch)' -or
            $content -match '(?i)(boiii(?:\.exe)?|blackops3|server_zm|dedicated)') {
            $preferred.Add($item) | Out-Null
        }
    }
    return @($preferred | Sort-Object FullName -Unique)
}

function Resolve-ServerLauncherPath {
    param([string]$Requested, [string]$Root, [object]$Config)

    foreach ($value in @($Requested, [string]$Config.server_launcher)) {
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        $candidate = $value
        if (-not [System.IO.Path]::IsPathRooted($candidate)) { $candidate = Join-Path $Root $candidate }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
    }

    $candidates = @(Get-LauncherCandidates -Root $Root)
    if ($candidates.Count -eq 1) { return $candidates[0].FullName }
    if ($candidates.Count -gt 1) {
        Write-Host "Several server launchers were found:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host (" [{0}] {1}" -f ($i + 1), $candidates[$i].Name) -ForegroundColor Gray
        }
        $choice = Read-Host "Choose the server launcher number"
        $index = 0
        if ([int]::TryParse($choice, [ref]$index) -and $index -ge 1 -and $index -le $candidates.Count) {
            return $candidates[$index - 1].FullName
        }
    }

    $entered = Read-Host "Full path to your existing BOIII server .bat or .cmd"
    if (-not (Test-Path -LiteralPath $entered -PathType Leaf)) {
        throw "Server launcher not found: $entered"
    }
    return [System.IO.Path]::GetFullPath($entered)
}

function Get-DpapiPlainText {
    param([string]$SecretPath)
    $encrypted = (Get-Content -LiteralPath $SecretPath -Raw -ErrorAction Stop).Trim()
    if ([string]::IsNullOrWhiteSpace($encrypted)) { throw "Empty encrypted RCON secret." }
    $secure = $encrypted | ConvertTo-SecureString -ErrorAction Stop
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

function Test-PinteModRconConfiguration {
    param(
        [string]$ServerCfg,
        [string]$SecretCfg,
        [string]$BridgeSecret,
        [string]$BridgeConfig
    )

    $cfgPassword = $null
    $dpapiPassword = $null
    try {
        foreach ($required in @($ServerCfg, $SecretCfg, $BridgeSecret, $BridgeConfig)) {
            if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
                return [pscustomobject]@{ Valid=$false; Reason="Missing local file: $required"; Address=""; Port=0 }
            }
        }

        $serverText = Get-Content -LiteralPath $ServerCfg -Raw -ErrorAction Stop
        if ($serverText -notmatch '(?im)^\s*exec\s+"?pintemod_server_secrets\.cfg"?\s*$') {
            return [pscustomobject]@{ Valid=$false; Reason="server_zm.cfg does not load pintemod_server_secrets.cfg"; Address=""; Port=0 }
        }

        $secretText = Get-Content -LiteralPath $SecretCfg -Raw -ErrorAction Stop
        $match = [regex]::Match($secretText, '(?im)^\s*(?:set\s+)?rcon_password\s+"(?<password>[^"\r\n]+)"\s*$')
        if (-not $match.Success) {
            return [pscustomobject]@{ Valid=$false; Reason="No valid rcon_password in pintemod_server_secrets.cfg"; Address=""; Port=0 }
        }
        $cfgPassword = $match.Groups['password'].Value
        $dpapiPassword = Get-DpapiPlainText -SecretPath $BridgeSecret
        if ($cfgPassword -cne $dpapiPassword) {
            return [pscustomobject]@{ Valid=$false; Reason="BOIII and GeoIP RCON secrets do not match"; Address=""; Port=0 }
        }

        $bridge = Get-Content -LiteralPath $BridgeConfig -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $address = [string]$bridge.server_address
        $port = [int]$bridge.server_port
        if ([string]::IsNullOrWhiteSpace($address) -or $port -lt 1 -or $port -gt 65535) {
            return [pscustomobject]@{ Valid=$false; Reason="Invalid GeoIP bridge address or port"; Address=$address; Port=$port }
        }

        return [pscustomobject]@{ Valid=$true; Reason="Existing local configuration verified"; Address=$address; Port=$port }
    }
    catch {
        return [pscustomobject]@{ Valid=$false; Reason=$_.Exception.Message; Address=""; Port=0 }
    }
    finally {
        $cfgPassword = $null
        $dpapiPassword = $null
    }
}

function Test-ToolAlreadyRunning {
    param([string]$ScriptPath)
    try {
        $escaped = [regex]::Escape([System.IO.Path]::GetFullPath($ScriptPath))
        return [bool](Get-CimInstance Win32_Process -ErrorAction Stop |
            Where-Object { $_.CommandLine -and $_.CommandLine -match $escaped } |
            Select-Object -First 1)
    }
    catch { return $false }
}

function Get-PinteModNamedProcesses {
    param([string]$ProcessName)

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($ProcessName)
    if ([string]::IsNullOrWhiteSpace($baseName)) { $baseName = 'boiii' }
    $exeName = $baseName + '.exe'

    try {
        return @(Get-CimInstance Win32_Process -Filter ("Name='{0}'" -f $exeName.Replace("'", "''")) -ErrorAction Stop)
    }
    catch {
        return @(Get-Process -Name $baseName -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{
                ProcessId = $_.Id
                Name = $_.ProcessName + '.exe'
                CommandLine = ''
            }
        })
    }
}

function Test-PinteModDedicatedServerProcess {
    param($Process)

    if (-not $Process) { return $false }
    $commandLine = [string]$Process.CommandLine
    if ([string]::IsNullOrWhiteSpace($commandLine)) { return $false }

    return [bool](
        $commandLine -match '(?i)(?:^|\s)-dedicated(?:\s|$)' -or
        $commandLine -match '(?i)\+set\s+dedicated\s+(?:1|true)\b' -or
        $commandLine -match '(?i)\+set\s+sv_config\s+[^\s"]*server_zm\.cfg\b'
    )
}

function Get-LogTail {
    param([string[]]$Paths)
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        try {
            $text = @(Get-Content -LiteralPath $path -Tail 12 -ErrorAction Stop) -join " | "
            if (-not [string]::IsNullOrWhiteSpace($text)) { $parts.Add($text.Trim()) | Out-Null }
        }
        catch { }
    }
    return ($parts -join " | ")
}

function Write-SupervisorLog {
    param([string]$Level, [string]$Message)
    if (-not $script:SupervisorLogPath) { return }
    $line = "[{0}][{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level.ToUpperInvariant(), (($Message -replace "[\r\n]+", ' ').Trim())
    Add-Content -LiteralPath $script:SupervisorLogPath -Value $line -Encoding UTF8
}

function Write-JsonAtomic {
    param([string]$Path, $Value)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temp = "$Path.tmp"
    $json = $Value | ConvertTo-Json -Depth 5 -Compress
    [System.IO.File]::WriteAllText($temp, $json, [System.Text.UTF8Encoding]::new($false))
    [void](Get-Content -LiteralPath $temp -Raw | ConvertFrom-Json -ErrorAction Stop)
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Write-SupervisorHeartbeat {
    param([string]$State='monitoring', [string]$LastErrorCode='')
    if (-not $script:SupervisorHeartbeatPath) { return }
    $script:SupervisorSequence++
    $value = [ordered]@{
        schema_version = 1
        tool = 'supervisor'
        version = '2.1.1'
        state = $State
        sequence = $script:SupervisorSequence
        updated_utc = [DateTime]::UtcNow.ToString('o')
        last_error_code = $LastErrorCode
        log = 'boiii/tools/runtime/PinteMod_Supervisor.log'
        privacy = 'No secret or player IP'
    }
    try { Write-JsonAtomic -Path $script:SupervisorHeartbeatPath -Value $value }
    catch { Write-SupervisorLog -Level 'WARN' -Message ('Heartbeat write failed: ' + $_.Exception.Message) }
}

function Start-PinteModTool {
    param(
        [string]$ScriptPath,
        [string]$Title,
        [string]$ServerRootArgument,
        [bool]$Visible
    )

    if (Test-ToolAlreadyRunning -ScriptPath $ScriptPath) {
        return [pscustomobject]@{ Process=$null; AlreadyRunning=$true; OutputLog=""; ErrorLog=""; Title=$Title; Warned=$false }
    }

    # Bundled tools live in <server-root>\boiii\tools and already resolve
    # the server root from $PSScriptRoot. Do not forward that path through
    # Start-Process: Windows PowerShell 5.1 may preserve a stray quote in
    # an argument containing spaces (for example UnrankedServer").
    $args = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $ScriptPath + '"'))

    $outputLog = ""
    $errorLog = ""

    if ($Visible) {
        # The supervisor itself normally runs in a hidden PowerShell window.
        # Starting another console application directly can make it inherit that
        # hidden console. Use START /WAIT through the helper BAT to force a new,
        # independent and visible console while retaining a process to monitor.
        $helperName = 'Launch_' + [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath) + '.bat'
        $helperPath = Join-Path (Split-Path -Parent $ScriptPath) $helperName
        if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
            throw "$Title helper launcher not found: $helperPath"
        }

        $escapedHelper = $helperPath.Replace('"', '""')
        $cmdLine = '/d /c start "" /wait "' + $escapedHelper + '"'
        $process = Start-Process -FilePath 'cmd.exe' -ArgumentList $cmdLine -WorkingDirectory (Split-Path -Parent $ScriptPath) -WindowStyle Hidden -PassThru
    }
    else {
        $runtimeRoot = Join-Path (Split-Path -Parent $ScriptPath) 'runtime'
        if (-not (Test-Path -LiteralPath $runtimeRoot)) {
            New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
        }
        $safeName = ([System.IO.Path]::GetFileNameWithoutExtension($ScriptPath) -replace '[^A-Za-z0-9_.-]', '_')
        $outputLog = Join-Path $runtimeRoot "$safeName.out.log"
        $errorLog = Join-Path $runtimeRoot "$safeName.error.log"
        Remove-Item -LiteralPath $outputLog, $errorLog -Force -ErrorAction SilentlyContinue

        $start = @{
            FilePath = 'powershell.exe'
            ArgumentList = $args
            WorkingDirectory = (Split-Path -Parent $ScriptPath)
            PassThru = $true
            WindowStyle = 'Hidden'
            RedirectStandardOutput = $outputLog
            RedirectStandardError = $errorLog
        }
        $process = Start-Process @start
    }
    Start-Sleep -Milliseconds 1500
    $process.Refresh()
    if ($process.HasExited) {
        $details = Get-LogTail -Paths @($errorLog, $outputLog)
        if ([string]::IsNullOrWhiteSpace($details)) { $details = "No diagnostic output was produced." }
        throw "$Title stopped during startup (exit code $($process.ExitCode)). $details"
    }

    return [pscustomobject]@{ Process=$process; AlreadyRunning=$false; OutputLog=$outputLog; ErrorLog=$errorLog; Title=$Title; Warned=$false }
}

function Wait-PinteModProcess {
    param(
        [System.Diagnostics.Process]$Process,
        [System.Collections.Generic.List[object]]$Tools
    )

    while ($true) {
        try { Write-SupervisorHeartbeat -State 'monitoring' } catch { }
        $Process.Refresh()
        if ($Process.HasExited) { break }

        foreach ($tool in $Tools) {
            try {
                if (-not $tool -or -not $tool.Process -or $tool.Warned) { continue }
                $tool.Process.Refresh()
                if ($tool.Process.HasExited) {
                    $details = Get-LogTail -Paths @($tool.ErrorLog, $tool.OutputLog)
                    if ([string]::IsNullOrWhiteSpace($details)) { $details = "No diagnostic output was produced." }
                    Write-Host "[ERROR] $($tool.Title) stopped unexpectedly (exit code $($tool.Process.ExitCode))." -ForegroundColor Red
                    Write-Host "        $details" -ForegroundColor DarkYellow
                    Write-SupervisorLog -Level 'ERROR' -Message "$($tool.Title) stopped unexpectedly (exit code $($tool.Process.ExitCode)): $details"
                    Write-SupervisorHeartbeat -State 'error' -LastErrorCode (($tool.Title -replace '\s+','_').ToUpperInvariant() + '_STOPPED')
                    $tool.Warned = $true
                }
            }
            catch { }
        }

        Start-Sleep -Seconds 2
    }
}

$toolProcesses = New-Object System.Collections.Generic.List[object]
try {
    $layout = Resolve-PinteModLayout -RequestedRoot $ServerRoot -RequestedPackageRoot $PackageRoot
    $serverRootPath = $layout.ServerRoot
    $boiiiRoot = $layout.BoiiiRoot
    $toolsRoot = Join-Path $boiiiRoot 'tools'
    $zoneRoot = Join-Path $serverRootPath 'zone'
    $runtimeRoot = Join-Path $toolsRoot 'runtime'
    $healthRoot = Join-Path $boiiiRoot 'scriptdata\pintemod\health'
    foreach ($path in @($runtimeRoot, $healthRoot)) {
        if (-not (Test-Path -LiteralPath $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    }
    $script:SupervisorLogPath = Join-Path $runtimeRoot 'PinteMod_Supervisor.log'
    $script:SupervisorHeartbeatPath = Join-Path $healthRoot 'supervisor.json'
    $script:SupervisorSequence = 0
    Write-SupervisorLog -Level 'INFO' -Message 'Supervisor starting.'
    Write-SupervisorHeartbeat -State 'configured'

    $serverCfg = Join-Path $zoneRoot 'server_zm.cfg'
    $secretCfg = Join-Path $zoneRoot 'pintemod_server_secrets.cfg'
    $bridgeSecret = Join-Path $toolsRoot 'PinteMod_GeoIP_Bridge.secret.txt'
    $bridgeConfig = Join-Path $toolsRoot 'PinteMod_GeoIP_Bridge.local.json'

    $rconWasCreated = $false
    $rconState = Test-PinteModRconConfiguration -ServerCfg $serverCfg -SecretCfg $secretCfg -BridgeSecret $bridgeSecret -BridgeConfig $bridgeConfig
    if ($ResetRcon -or -not $rconState.Valid) {
        if ($ResetRcon) {
            Write-Host "RCON reset requested." -ForegroundColor Yellow
        }
        else {
            Write-Host "PinteMod RCON requires configuration: $($rconState.Reason)" -ForegroundColor Yellow
        }
        Write-Host "The password is created locally and is never included in the public package." -ForegroundColor Gray
        & (Join-Path $toolsRoot 'Configure_PinteMod_Server_Secrets.ps1') -ServerRoot $serverRootPath
        $rconWasCreated = $true
        $rconState = Test-PinteModRconConfiguration -ServerCfg $serverCfg -SecretCfg $secretCfg -BridgeSecret $bridgeSecret -BridgeConfig $bridgeConfig
        if (-not $rconState.Valid) {
            throw "RCON configuration validation failed: $($rconState.Reason)"
        }
    }

    $examplePath = Join-Path $toolsRoot 'PinteMod_Server_Launcher.example.json'
    $localPath = Join-Path $toolsRoot 'PinteMod_Server_Launcher.local.json'
    if (Test-Path -LiteralPath $localPath) {
        $config = Get-Content -LiteralPath $localPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    elseif (Test-Path -LiteralPath $examplePath) {
        $config = Get-Content -LiteralPath $examplePath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    else {
        $config = [pscustomobject]@{
            server_launcher = ''
            server_process_name = 'boiii'
            tool_start_delay_seconds = 5
            server_start_timeout_seconds = 90
            launch_ban_service = $true
            launch_geoip = $true
            launch_live_console = $true
        }
    }

    if (-not $config.PSObject.Properties['launch_ban_service']) {
        $config | Add-Member -NotePropertyName launch_ban_service -NotePropertyValue $true
    }
    if (-not $config.PSObject.Properties['launch_geoip']) {
        $config | Add-Member -NotePropertyName launch_geoip -NotePropertyValue $true
    }
    if (-not $config.PSObject.Properties['launch_live_console']) {
        $config | Add-Member -NotePropertyName launch_live_console -NotePropertyValue $true
    }

    $launcherPath = Resolve-ServerLauncherPath -Requested $ServerLauncher -Root $serverRootPath -Config $config
    $relativeLauncher = $launcherPath
    if ($launcherPath.StartsWith($serverRootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativeLauncher = $launcherPath.Substring($serverRootPath.Length).TrimStart('\')
    }
    $config.server_launcher = $relativeLauncher
    Write-Utf8NoBom -Path $localPath -Content ($config | ConvertTo-Json -Depth 6)

    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host " PinteMod v2.1.1" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host " Server root : $serverRootPath" -ForegroundColor Gray
    Write-Host " Launcher    : $launcherPath" -ForegroundColor Gray
    if ($rconWasCreated) {
        Write-Host " RCON        : new local configuration created and verified" -ForegroundColor Green
    }
    else {
        Write-Host " RCON        : existing local configuration verified ($($rconState.Address):$($rconState.Port))" -ForegroundColor Green
    }
    Write-Host " Background  : Ban Service and GeoIP (logs in boiii\tools\runtime)" -ForegroundColor Gray
    Write-Host " Visible     : BOIII server console and Live Console" -ForegroundColor Gray
    Write-Host ""

    if (-not $ServerOnly -and [bool]$config.launch_ban_service) {
        $result = Start-PinteModTool -ScriptPath (Join-Path $toolsRoot 'PinteMod_Ban_Service.ps1') -Title 'Ban Service' -ServerRootArgument $serverRootPath -Visible $false
        if ($result.AlreadyRunning) {
            Write-Host "[SKIP] Ban Service is already running." -ForegroundColor Yellow
        }
        else {
            $toolProcesses.Add($result) | Out-Null
            Write-Host "[OK] Ban Service is running in the background." -ForegroundColor Green
            Write-SupervisorLog -Level 'INFO' -Message 'Ban Service started in background.' 
        }
    }

    $processName = [string]$config.server_process_name
    if ([string]::IsNullOrWhiteSpace($processName)) { $processName = 'boiii' }
    $processBaseName = [System.IO.Path]::GetFileNameWithoutExtension($processName)
    if ([string]::IsNullOrWhiteSpace($processBaseName)) { $processBaseName = 'boiii' }

    $existingProcessDetails = @(Get-PinteModNamedProcesses -ProcessName $processBaseName)
    $existingServerProcesses = @($existingProcessDetails | Where-Object { Test-PinteModDedicatedServerProcess -Process $_ })
    if ($existingServerProcesses.Count -gt 0) {
        $existingServerPids = (($existingServerProcesses | ForEach-Object { [int]$_.ProcessId }) -join ',')
        throw "A BOIII dedicated server is already running (PID $existingServerPids). Stop it before launching another PinteMod server."
    }

    $existingIds = @($existingProcessDetails | ForEach-Object { [int]$_.ProcessId })
    if ($existingIds.Count -gt 0) {
        $clientPids = ($existingIds -join ',')
        Write-Host "[INFO] Existing BOIII client detected (PID $clientPids); it will be ignored by server monitoring." -ForegroundColor DarkCyan
        Write-SupervisorLog -Level 'INFO' -Message "Existing BOIII client process ignored before server launch (PID $clientPids)."
    }

    $quotedLauncher = '"' + $launcherPath + '"'
    $serverLauncherProcess = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $quotedLauncher) -WorkingDirectory (Split-Path -Parent $launcherPath) -PassThru
    Write-Host "[OK] BOIII server launcher started." -ForegroundColor Green
    Write-SupervisorLog -Level 'INFO' -Message "BOIII launcher started: $launcherPath"

    $delay = [int]$config.tool_start_delay_seconds
    if ($delay -lt 0) { $delay = 0 }
    Start-Sleep -Seconds $delay

    if (-not $ServerOnly -and [bool]$config.launch_geoip) {
        $result = Start-PinteModTool -ScriptPath (Join-Path $toolsRoot 'PinteMod_GeoIP_Bridge.ps1') -Title 'GeoIP bridge' -ServerRootArgument $serverRootPath -Visible $false
        if ($result.AlreadyRunning) {
            Write-Host "[SKIP] GeoIP bridge is already running." -ForegroundColor Yellow
        }
        else {
            $toolProcesses.Add($result) | Out-Null
            Write-Host "[OK] GeoIP bridge is running in the background." -ForegroundColor Green
            Write-SupervisorLog -Level 'INFO' -Message 'GeoIP bridge started in background.' 
        }
    }
    if (-not $ServerOnly -and [bool]$config.launch_live_console) {
        $result = Start-PinteModTool -ScriptPath (Join-Path $toolsRoot 'PinteMod_LiveConsole.ps1') -Title 'Live Console' -ServerRootArgument $serverRootPath -Visible $true
        if ($result.AlreadyRunning) {
            Write-Host "[SKIP] Live Console is already running." -ForegroundColor Yellow
        }
        else {
            $toolProcesses.Add($result) | Out-Null
            Write-Host "[OK] Live Console started." -ForegroundColor Green
            Write-SupervisorLog -Level 'INFO' -Message 'Live Console started.' 
        }
    }

    $timeout = [int]$config.server_start_timeout_seconds
    if ($timeout -lt 10) { $timeout = 10 }
    $deadline = (Get-Date).AddSeconds($timeout)
    $serverProcess = $null
    do {
        $serverProcess = Get-Process -Name $processBaseName -ErrorAction SilentlyContinue |
            Where-Object { $_.Id -notin $existingIds } |
            Select-Object -First 1
        if ($serverProcess) { break }
        if ($serverLauncherProcess.HasExited) {
            Start-Sleep -Milliseconds 500
        }
        else {
            Start-Sleep -Seconds 1
        }
    } while ((Get-Date) -lt $deadline)

    if ($serverProcess) {
        Write-Host "[OK] Monitoring server process PID $($serverProcess.Id)." -ForegroundColor Green
        Write-SupervisorLog -Level 'INFO' -Message "Monitoring BOIII PID $($serverProcess.Id)."
        Write-SupervisorHeartbeat -State 'monitoring' 
        Wait-PinteModProcess -Process $serverProcess -Tools $toolProcesses
    }
    elseif (-not $serverLauncherProcess.HasExited) {
        Write-Host "[WARN] BOIII process name was not detected; monitoring the server launcher instead." -ForegroundColor Yellow
        Wait-PinteModProcess -Process $serverLauncherProcess -Tools $toolProcesses
    }
    else {
        throw "The server launcher exited before a '$processName' process was detected. Verify server_process_name and the configured BOIII launcher."
    }
}
catch {
    $message = $_.Exception.Message
    try { Write-SupervisorLog -Level 'ERROR' -Message $message } catch { }
    try { Write-SupervisorHeartbeat -State 'error' -LastErrorCode 'SUPERVISOR_FATAL' } catch { }
    Write-Error $message
    exit 1
}
finally {
    try { Write-SupervisorLog -Level 'INFO' -Message 'Supervisor stopping child tools.' } catch { }
    try { Write-SupervisorHeartbeat -State 'stopped' } catch { }
    foreach ($tool in $toolProcesses) {
        try {
            $process = $tool.Process
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
