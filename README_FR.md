param(
    [string]$ServerAddress = "",
    [int]$ServerPort = 27018,
    [string]$SecretPath = "",
    [string]$RemoteDataRoot = "",
    [int]$TimeoutMs = 3500,
    [int]$FeedbackWaitMs = 2200
)

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'PinteMod v2.1.1 - Remote RCON Console'

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Save-RconSecret {
    param([string]$Path)

    $parent = Split-Path -Parent $Path
    if ($parent) { Ensure-Directory $parent }

    Write-Host ''
    Write-Host 'Enter the same RCON password used by the BOIII server.' -ForegroundColor Cyan
    Write-Host 'It will be encrypted for THIS Windows account only.' -ForegroundColor DarkGray
    $secure = Read-Host 'RCON password' -AsSecureString
    if ($secure.Length -le 0) { throw 'Empty RCON password.' }

    $encrypted = $secure | ConvertFrom-SecureString
    [System.IO.File]::WriteAllText(
        $Path,
        $encrypted,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Get-RconPassword {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Save-RconSecret -Path $Path
    }

    try {
        $encrypted = (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop).Trim()
        if ([string]::IsNullOrWhiteSpace($encrypted)) { throw 'Empty secret.' }
        $secure = $encrypted | ConvertTo-SecureString -ErrorAction Stop
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    }
    catch {
        throw 'Unable to decrypt the RCON password on this Windows account. Delete the local secret file and relaunch.'
    }
}

function Invoke-BoiiiRcon {
    param(
        [string]$Address,
        [int]$Port,
        [string]$Password,
        [string]$Command,
        [int]$Timeout
    )

    $client = [System.Net.Sockets.UdpClient]::new()
    $client.Client.ReceiveTimeout = $Timeout
    $client.Client.SendTimeout = $Timeout

    try {
        $client.Connect($Address, $Port)
        $prefix = [byte[]](0xFF,0xFF,0xFF,0xFF)
        $body = [System.Text.Encoding]::UTF8.GetBytes("rcon $Password $Command")
        $packet = New-Object byte[] ($prefix.Length + $body.Length)
        [Array]::Copy($prefix, 0, $packet, 0, $prefix.Length)
        [Array]::Copy($body, 0, $packet, $prefix.Length, $body.Length)
        [void]$client.Send($packet, $packet.Length)

        $remote = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 0)
        $response = $client.Receive([ref]$remote)
        if (-not $response -or $response.Length -le 4) { return '' }

        $text = [System.Text.Encoding]::UTF8.GetString($response, 4, $response.Length - 4)
        return ($text -replace '(?i)^print[\s\r\n]+', '').TrimEnd()
    }
    finally {
        $client.Dispose()
    }
}


function Get-RemoteDataRoot {
    param(
        [string]$RequestedRoot,
        [string]$Address
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        if (Test-Path -LiteralPath $RequestedRoot) {
            return [System.IO.Path]::GetFullPath($RequestedRoot.Trim('"'))
        }
        return ''
    }

    $configPath = Join-Path $PSScriptRoot 'PinteMod_Remote_Control.local.json'
    if (Test-Path -LiteralPath $configPath) {
        try {
            $config = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop |
                ConvertFrom-Json -ErrorAction Stop

            $configured = [string]$config.remote_data_root
            if (-not [string]::IsNullOrWhiteSpace($configured) -and
                (Test-Path -LiteralPath $configured)) {
                return [System.IO.Path]::GetFullPath($configured.Trim('"'))
            }
        }
        catch {
            # Keep RCON usable even if the optional local launcher config is invalid.
        }
    }

    $fallback = "\\$Address\PinteModData"
    if (Test-Path -LiteralPath $fallback) {
        return $fallback
    }

    return ''
}

function Get-FeedbackCommandName {
    param([string]$Command)

    if ([string]::IsNullOrWhiteSpace($Command)) { return '' }

    $first = ($Command.Trim() -split '\s+', 2)[0].ToLowerInvariant()

    switch ($first) {
        'ezzpausestatus' { return 'ezzpausestatus' }
        default { return '' }
    }
}

function Get-FeedbackSnapshot {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or
        -not (Test-Path -LiteralPath $Path)) {
        return ''
    }

    try {
        return [string](Get-Content -LiteralPath $Path -Raw -ErrorAction Stop)
    }
    catch {
        return ''
    }
}

function Read-PinteModFeedback {
    param(
        [string]$Content,
        [string]$ExpectedCommand
    )

    if ([string]::IsNullOrWhiteSpace($Content)) { return $null }

    $normalized = $Content -replace "`r`n", "`n"
    if (-not $normalized.StartsWith("PINTEMOD_REMOTE_FEEDBACK_V1`n")) {
        return $null
    }

    $commandMatch = [regex]::Match(
        $normalized,
        '(?m)^command=(?<command>[^\r\n]+)$'
    )
    if (-not $commandMatch.Success) { return $null }

    $commandName = $commandMatch.Groups['command'].Value.Trim()
    if (-not [string]::Equals(
        $commandName,
        $ExpectedCommand,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        return $null
    }

    $bodyMatch = [regex]::Match(
        $normalized,
        '(?s)---\n(?<body>.*?)\nEND(?:\n|$)'
    )
    if (-not $bodyMatch.Success) { return $null }

    $lines = @(
        $bodyMatch.Groups['body'].Value -split "`n" |
        ForEach-Object { $_.TrimEnd() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    return [PSCustomObject]@{
        Command = $commandName
        Lines = $lines
    }
}

function Wait-PinteModFeedback {
    param(
        [string]$Path,
        [string]$ExpectedCommand,
        [string]$PreviousContent,
        [int]$WaitMs
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or
        [string]::IsNullOrWhiteSpace($ExpectedCommand)) {
        return $null
    }

    $deadline = [DateTime]::UtcNow.AddMilliseconds([Math]::Max(250, $WaitMs))

    do {
        Start-Sleep -Milliseconds 100
        $current = Get-FeedbackSnapshot -Path $Path

        if (-not [string]::IsNullOrWhiteSpace($current) -and
            $current -ne $PreviousContent) {
            $parsed = Read-PinteModFeedback `
                -Content $current `
                -ExpectedCommand $ExpectedCommand

            if ($parsed) { return $parsed }
        }
    }
    while ([DateTime]::UtcNow -lt $deadline)

    return $null
}

function Test-SensitiveRconCommand {
    param(
        [string]$Command,
        [string]$Password
    )

    if ([string]::IsNullOrWhiteSpace($Command)) { return $false }

    if (-not [string]::IsNullOrEmpty($Password) -and
        $Command.IndexOf(
            $Password,
            [System.StringComparison]::Ordinal
        ) -ge 0) {
        return $true
    }

    return $Command -match '(?i)(^|[\s=])(rcon_password|password|secret|token|api[_-]?key|authorization|bearer)([\s=]|$)'
}

function Write-RconAudit {
    param(
        [string]$Path,
        [string]$Command,
        [bool]$Sensitive
    )

    if ($Sensitive -or [string]::IsNullOrWhiteSpace($Command)) { return }

    $line = '[{0}] COMMAND | {1}' -f (
        Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    ), $Command

    try {
        Add-Content -LiteralPath $Path -Value $line -Encoding UTF8
    }
    catch {
        # Local audit is best-effort and must never break RCON.
    }
}

function Show-Help {
    Write-Host ''
    Write-Host 'Local commands:' -ForegroundColor Cyan
    Write-Host '  .help       show this help' -ForegroundColor Gray
    Write-Host '  .clear      clear this window' -ForegroundColor Gray
    Write-Host '  .password   replace the locally encrypted RCON password' -ForegroundColor Gray
    Write-Host '  .quit       close the remote console' -ForegroundColor Gray
    Write-Host ''
    Write-Host 'Everything else is sent to BOIII, for example:' -ForegroundColor Cyan
    Write-Host '  ezzhealth full' -ForegroundColor Gray
    Write-Host '  status' -ForegroundColor Gray
    Write-Host '  say Hello' -ForegroundColor Gray
    Write-Host '  map zm_castle' -ForegroundColor Gray
    Write-Host ''
    Write-Host 'PinteMod remote feedback:' -ForegroundColor Cyan
    Write-Host '  ezzpausestatus  returns its PinteMod status here when the LAN data share is reachable' -ForegroundColor Gray
    Write-Host ''
}

if ([string]::IsNullOrWhiteSpace($ServerAddress)) {
    $ServerAddress = Read-Host 'Laptop/server LAN IP (example: 192.168.1.90)'
}
if ([string]::IsNullOrWhiteSpace($ServerAddress)) { throw 'Server address is required.' }
if ($ServerPort -le 0 -or $ServerPort -gt 65535) { throw 'Invalid server port.' }

if ([string]::IsNullOrWhiteSpace($SecretPath)) {
    $runtime = Join-Path $PSScriptRoot 'runtime'
    Ensure-Directory $runtime
    $SecretPath = Join-Path $runtime 'PinteMod_Remote_RCON.secret.txt'
}

$password = Get-RconPassword -Path $SecretPath

$runtime = Join-Path $PSScriptRoot 'runtime'
Ensure-Directory $runtime
$auditPath = Join-Path $runtime 'PinteMod_Remote_RCON.audit.log'

$resolvedRemoteDataRoot = Get-RemoteDataRoot `
    -RequestedRoot $RemoteDataRoot `
    -Address $ServerAddress

$feedbackPath = ''
if (-not [string]::IsNullOrWhiteSpace($resolvedRemoteDataRoot)) {
    $feedbackPath = Join-Path $resolvedRemoteDataRoot 'remote\feedback.latest.txt'
}

Clear-Host
Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host ' PinteMod v2.1.1 - Remote RCON Console' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host (" Target : {0}:{1}" -f $ServerAddress, $ServerPort) -ForegroundColor Gray
Write-Host ' Link   : BOIII RCON over your LAN' -ForegroundColor Gray
Write-Host ' Secret : encrypted locally with Windows DPAPI' -ForegroundColor DarkGray
if (-not [string]::IsNullOrWhiteSpace($resolvedRemoteDataRoot)) {
    Write-Host (" Data   : {0} (read-only)" -f $resolvedRemoteDataRoot) -ForegroundColor Gray
    Write-Host ' Reply  : PinteMod remote feedback enabled for supported status commands' -ForegroundColor Green
}
else {
    Write-Host ' Reply  : PinteMod remote feedback unavailable; normal RCON still works' -ForegroundColor Yellow
}
Write-Host ' Audit  : safe RCON commands are logged locally for Live Console echo' -ForegroundColor DarkGray
Write-Host ' Type .help for help. Type .quit to close.' -ForegroundColor DarkGray
Write-Host ''

while ($true) {
    $command = Read-Host 'RCON'
    if ($null -eq $command) { continue }
    $command = $command.Trim()
    if ($command -eq '') { continue }

    $localCommand = $command.ToLowerInvariant()
    if ($localCommand -in @('.quit', '.exit')) {
        return
    }
    if ($localCommand -in @('.clear', '.cls')) {
        Clear-Host
        continue
    }
    if ($localCommand -eq '.help') {
        Show-Help
        continue
    }
    if ($localCommand -eq '.password') {
        Remove-Item -LiteralPath $SecretPath -Force -ErrorAction SilentlyContinue
        Save-RconSecret -Path $SecretPath
        $password = Get-RconPassword -Path $SecretPath

        Write-Host '[OK] Local RCON password replaced.' -ForegroundColor Green
        Write-Host '[INFO] Password kept local; nothing was sent to BOIII.' -ForegroundColor DarkGray
        Write-Host ''
        continue
    }
    $containsPassword = -not [string]::IsNullOrEmpty($password) -and
        $command.IndexOf(
            $password,
            [System.StringComparison]::Ordinal
        ) -ge 0

    if ($containsPassword) {
        Write-Host '[WARN] This input contains your RCON password. It was NOT sent to BOIII.' -ForegroundColor Yellow
        Write-Host 'Use .password only when you want to replace the saved password.' -ForegroundColor DarkGray
        Write-Host ''
        continue
    }

    $sensitiveCommand = Test-SensitiveRconCommand `
        -Command $command `
        -Password $password

    Write-RconAudit `
        -Path $auditPath `
        -Command $command `
        -Sensitive $sensitiveCommand

    $feedbackCommand = Get-FeedbackCommandName -Command $command
    $feedbackBefore = ''
    if (-not [string]::IsNullOrWhiteSpace($feedbackCommand) -and
        -not [string]::IsNullOrWhiteSpace($feedbackPath)) {
        $feedbackBefore = Get-FeedbackSnapshot -Path $feedbackPath
    }

    try {
        $answer = Invoke-BoiiiRcon `
            -Address $ServerAddress `
            -Port $ServerPort `
            -Password $password `
            -Command $command `
            -Timeout $TimeoutMs

        $feedback = $null
        if (-not [string]::IsNullOrWhiteSpace($feedbackCommand) -and
            -not [string]::IsNullOrWhiteSpace($feedbackPath)) {
            $feedback = Wait-PinteModFeedback `
                -Path $feedbackPath `
                -ExpectedCommand $feedbackCommand `
                -PreviousContent $feedbackBefore `
                -WaitMs $FeedbackWaitMs
        }

        if (-not [string]::IsNullOrWhiteSpace($answer)) {
            Write-Host $answer -ForegroundColor Gray
        }

        if ($feedback) {
            Write-Host '[PinteMod feedback]' -ForegroundColor Cyan
            foreach ($line in $feedback.Lines) {
                Write-Host ('  ' + $line) -ForegroundColor Gray
            }
        }
        elseif ([string]::IsNullOrWhiteSpace($answer)) {
            if (-not [string]::IsNullOrWhiteSpace($feedbackCommand) -and
                -not [string]::IsNullOrWhiteSpace($feedbackPath)) {
                Write-Host '[OK] Command sent; no fresh PinteMod feedback was received.' -ForegroundColor DarkGray
            }
            else {
                Write-Host '[OK] Command sent; BOIII returned no text.' -ForegroundColor DarkGray
            }
        }
    }
    catch [System.Net.Sockets.SocketException] {
        Write-Host '[ERROR] No RCON answer.' -ForegroundColor Red
        Write-Host 'Check: laptop IP, port, Windows firewall, server running, RCON password.' -ForegroundColor Yellow
    }
    catch {
        Write-Host ('[ERROR] ' + $_.Exception.Message) -ForegroundColor Red
    }

    Write-Host ''
}
