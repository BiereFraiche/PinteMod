param(
    [string]$ServerRoot = "",
    [string]$RemoteDataRoot = "",
    [int]$InitialLines = 12,
    [switch]$EnableCriticalSound
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "PinteMod v2.1.1 - Live Console"

$script:LiveConsoleRuntimeRoot = Join-Path $PSScriptRoot 'runtime'
$script:LiveConsoleErrorLog = Join-Path $script:LiveConsoleRuntimeRoot 'PinteMod_LiveConsole.error.log'
if (-not (Test-Path -LiteralPath $script:LiveConsoleRuntimeRoot)) {
    New-Item -ItemType Directory -Path $script:LiveConsoleRuntimeRoot -Force | Out-Null
}
Remove-Item -LiteralPath $script:LiveConsoleErrorLog -Force -ErrorAction SilentlyContinue

trap {
    $details = ($_ | Out-String).Trim()
    $entry = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $details
    try { Add-Content -LiteralPath $script:LiveConsoleErrorLog -Value $entry -Encoding UTF8 } catch { }
    try {
        Write-Host ""
        Write-Host "[ERROR] PinteMod Live Console stopped." -ForegroundColor Red
        Write-Host $details -ForegroundColor Yellow
        Write-Host ("Journal: {0}" -f $script:LiveConsoleErrorLog) -ForegroundColor DarkGray
    } catch { }
    try {
        if ($mutex) {
            if ($mutexOwned) { $mutex.ReleaseMutex() | Out-Null }
            $mutex.Dispose()
        }
    } catch { }
    exit 1
}

try {
    $Host.UI.RawUI.BackgroundColor = 'Black'
    $Host.UI.RawUI.ForegroundColor = 'Gray'
    Clear-Host
}
catch { }

$mutex = New-Object System.Threading.Mutex($false, "Global\PinteMod_v2_1_LiveConsole")
$mutexOwned = $false
try { $mutexOwned = $mutex.WaitOne(0, $false) }
catch [System.Threading.AbandonedMutexException] { $mutexOwned = $true }
if (-not $mutexOwned) {
    $mutex.Dispose()
    throw "PinteMod Live Console is already running."
}

function Resolve-ServerRoot {
    param([string]$RequestedRoot)

    function Test-RootCandidate {
        param([string]$Candidate)

        if ([string]::IsNullOrWhiteSpace($Candidate)) { return $null }

        try {
            $full = [System.IO.Path]::GetFullPath($Candidate.Trim('"'))
        }
        catch {
            return $null
        }

        if (Test-Path -LiteralPath (Join-Path $full "boiii")) {
            return $full
        }

        if ((Split-Path -Leaf $full) -ieq "boiii") {
            $parent = Split-Path -Parent $full
            if (-not [string]::IsNullOrWhiteSpace($parent) -and
                (Test-Path -LiteralPath $full)) {
                return [System.IO.Path]::GetFullPath($parent)
            }
        }

        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        $resolved = Test-RootCandidate -Candidate $RequestedRoot
        if ($resolved) { return $resolved }
        throw "The supplied server root does not contain a boiii folder: $RequestedRoot"
    }

    $seeds = @($PSScriptRoot, (Get-Location).Path) | Select-Object -Unique
    foreach ($seed in $seeds) {
        $candidate = $seed
        for ($depth = 0; $depth -lt 6 -and -not [string]::IsNullOrWhiteSpace($candidate); $depth++) {
            $resolved = Test-RootCandidate -Candidate $candidate
            if ($resolved) { return $resolved }

            $parent = Split-Path -Parent $candidate
            if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $candidate) { break }
            $candidate = $parent
        }
    }

    Write-Host "PinteMod could not automatically locate the server root." -ForegroundColor Yellow
    $entered = Read-Host "Folder that directly contains boiii"
    if ([string]::IsNullOrWhiteSpace($entered)) { throw "No server root supplied." }

    $resolved = Test-RootCandidate -Candidate $entered
    if (-not $resolved) {
        throw "The selected folder does not contain boiii: $entered"
    }
    return $resolved
}

function Resolve-RemoteDataRoot {
    param([string]$RequestedRoot)

    if ([string]::IsNullOrWhiteSpace($RequestedRoot)) {
        throw "Remote data folder is empty."
    }

    try {
        $full = [System.IO.Path]::GetFullPath($RequestedRoot.Trim('"'))
    }
    catch {
        throw "Invalid remote data folder: $RequestedRoot"
    }

    if (-not (Test-Path -LiteralPath $full)) {
        throw "Remote PinteMod data folder is not reachable: $full"
    }

    $logs = Join-Path $full 'logs'
    if (-not (Test-Path -LiteralPath $logs)) {
        throw "Remote folder does not look like boiii\\scriptdata\\pintemod (logs folder missing): $full"
    }

    return $full
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-AtomicJson {
    param([string]$Path, $Value)
    $parent = Split-Path -Parent $Path
    Ensure-Directory $parent
    $temp = "$Path.tmp"
    $json = $Value | ConvertTo-Json -Depth 6 -Compress
    [System.IO.File]::WriteAllText($temp, $json, [System.Text.UTF8Encoding]::new($false))
    [void](Get-Content -LiteralPath $temp -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Write-LiveHeartbeat {
    param([string]$State = 'running', [string]$LastErrorCode = '')
    if (-not $script:HeartbeatPath) { return }
    $script:HeartbeatSequence++
    $value = [ordered]@{
        schema_version = 1
        tool = 'live_console'
        version = '2.1.1'
        state = $State
        sequence = $script:HeartbeatSequence
        updated_utc = [DateTime]::UtcNow.ToString('o')
        filter = $script:ActiveFilter
        session = if ($script:Manifest) { [string]$script:Manifest.session_id } else { 'waiting' }
        last_error_code = $LastErrorCode
        read_only = $true
        privacy = 'No player IP or GUID displayed'
    }
    Write-AtomicJson -Path $script:HeartbeatPath -Value $value
}

function Read-SessionManifest {
    param([string]$Root)

    $manifestPath = Join-Path $Root "current_session.json"
    if (Test-Path -LiteralPath $manifestPath) {
        try {
            $raw = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop
            $manifest = $raw | ConvertFrom-Json -ErrorAction Stop
            if ($manifest.session_id) { return $manifest }
        }
        catch {
            Write-Host "[WARN] Invalid current_session.json: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    $sessionsRoot = Join-Path $Root "sessions"
    if (Test-Path -LiteralPath $sessionsRoot) {
        $latest = Get-ChildItem -LiteralPath $sessionsRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) {
            return [PSCustomObject]@{
                session_id = $latest.Name
                map = ($latest.Name -replace '_s\d+_\d+$', '')
                started_gettime = "unknown"
                fallback = $true
            }
        }
    }

    return [PSCustomObject]@{
        session_id = "waiting_for_server"
        map = "unknown"
        started_gettime = "unknown"
        fallback = $true
    }
}

function Get-SessionRoot {
    param($Manifest, [string]$Root)
    return Join-Path (Join-Path $Root "sessions") ([string]$Manifest.session_id)
}

function Get-SourceDefinitions {
    param([string]$SessionRoot)

    $sources = @(
        [PSCustomObject]@{ Tag="JOIN";      Category="JOIN";      Path=(Join-Path $SessionRoot "connections.log");         Color="Cyan" },
        [PSCustomObject]@{ Tag="CHAT";      Category="CHAT";      Path=(Join-Path $SessionRoot "chat\session.log");       Color="White" },
        [PSCustomObject]@{ Tag="COMMAND";   Category="CHAT";      Path=(Join-Path $SessionRoot "chat\commands.log");      Color="DarkGray" },
        [PSCustomObject]@{ Tag="COMMUNITY"; Category="COMMUNITY"; Path=(Join-Path $SessionRoot "community.log");           Color="Green" },
        [PSCustomObject]@{ Tag="VOTE";      Category="VOTE";      Path=(Join-Path $SessionRoot "vote_summary.log");        Color="Yellow" },
        [PSCustomObject]@{ Tag="KICK";      Category="KICK";      Path=(Join-Path $SessionRoot "votekick_summary.log");    Color="Magenta" },
        [PSCustomObject]@{ Tag="BAN";       Category="BAN";       Path=(Join-Path $SessionRoot "moderation.log");          Color="Magenta" },
        [PSCustomObject]@{ Tag="BAN-SVC";   Category="BAN";       Path=(Join-Path $script:DataRoot "bans\service.log"); Color="DarkMagenta" },
        [PSCustomObject]@{ Tag="IDENTITY";  Category="IDENTITY";  Path=(Join-Path $SessionRoot "identity.log");            Color="DarkCyan" },
        [PSCustomObject]@{ Tag="RANKS";     Category="RANKS";     Path=(Join-Path $SessionRoot "ranks.log");               Color="Blue" },
        [PSCustomObject]@{ Tag="EE";        Category="EE";        Path=(Join-Path $SessionRoot "easter_eggs.log");         Color="DarkYellow" },
        [PSCustomObject]@{ Tag="MENU";      Category="MENU";      Path=(Join-Path $SessionRoot "menu.log");                Color="DarkGreen" },
        [PSCustomObject]@{ Tag="STORAGE";   Category="STORAGE";   Path=(Join-Path $SessionRoot "storage.log");             Color="DarkMagenta" },
        [PSCustomObject]@{ Tag="LANG";      Category="LANGUAGE";  Path=(Join-Path $SessionRoot "localization.log");        Color="DarkCyan" }
    )

    # Community Pause is currently experimental and writes one global operator
    # log below pintemod\logs. The LAN viewer only reads it.
    $sources += [PSCustomObject]@{
        Tag="PAUSE"
        Category="COMMUNITY"
        Path=(Join-Path $script:DataRoot "logs\pause.log")
        Color="Cyan"
    }

    # Remote RCON writes this audit only on the operator PC. It never writes
    # RCON passwords/secrets and lets Live Console echo safe commands.
    if ($script:RemoteReadOnly) {
        $sources += [PSCustomObject]@{
            Tag="RCON"
            Category="COMMUNITY"
            Path=(Join-Path $script:LiveConsoleRuntimeRoot "PinteMod_Remote_RCON.audit.log")
            Color="DarkCyan"
        }
    }

    if (-not $script:RemoteReadOnly) {
        $consoleCandidates = @(
            (Join-Path $script:ServerRoot "boiii\console.log"),
            (Join-Path $script:ServerRoot "boiii\boiii.log"),
            (Join-Path $script:ServerRoot "boiii\logs\console.log"),
            (Join-Path $script:ServerRoot "main\console_mp.log")
        ) | Select-Object -Unique

        foreach ($candidate in $consoleCandidates) {
            if (Test-Path -LiteralPath $candidate) {
                $sources += [PSCustomObject]@{ Tag="SERVER"; Category="ERROR"; Path=$candidate; Color="Gray" }
            }
        }

        $runtimeRoot = Join-Path $script:ServerRoot 'boiii\tools\runtime'
        $sources += [PSCustomObject]@{ Tag='SUPERVISOR'; Category='WARN'; Path=(Join-Path $runtimeRoot 'PinteMod_Supervisor.log'); Color='DarkYellow' }
        $sources += [PSCustomObject]@{ Tag='SUP-BOOT'; Category='ERROR'; Path=(Join-Path $runtimeRoot 'PinteMod_Supervisor.bootstrap.error.log'); Color='Red' }
        $sources += [PSCustomObject]@{ Tag='BAN-ERR'; Category='ERROR'; Path=(Join-Path $runtimeRoot 'PinteMod_Ban_Service.error.log'); Color='Red' }
        $sources += [PSCustomObject]@{ Tag='GEOIP-ERR'; Category='ERROR'; Path=(Join-Path $runtimeRoot 'PinteMod_GeoIP_Bridge.error.log'); Color='Red' }
    }

    return $sources
}

function Protect-VisibleText {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return $Text }

    # The native BOIII console may echo RCON status output. Never expose
    # player addresses in the PinteMod Live Console or its exports.
    return ($Text -replace '(?<![0-9])(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?::[0-9]{1,5})?', '<ip-redacted>')
}

function Test-CriticalLine {
    param([string]$Text)
    return $Text -match '(?i)(\[FAIL\]|WRITE_FAILED|VERIFY_FAILED|CORRUPT|unresolved external|script error|fatal|exception|hitch warning|clientfield mismatch)'
}

function Get-LineColor {
    param([string]$DefaultColor, [string]$Text)
    if (Test-CriticalLine $Text) { return "Red" }
    if ($Text -match '(?i)(\[PASS\]|RECORD_|CANDIDATE_STORED|role=owner|role=admin)') { return "Green" }
    if ($Text -match '(?i)(UNRANKED|ROLLBACK|REJECTED|BLOCKED|warning)') { return "Yellow" }
    return $DefaultColor
}

function Test-DiagnosticLine {
    param([string]$Tag, [string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }

    # Detailed startup information remains available in the source logs and
    # status commands, but is hidden from the normal operator view.
    if ($Text -match '(?i)\bMODULE_LOADED\b') { return $true }
    if ($Text -match '(?i)\bPROFILE_ARMED\b') { return $true }
    if ($Text -match '(?i)^=== PinteMod session=') { return $true }
    if ($Text -match '(?i)^=== PinteMod .* loaded ===$') { return $true }

    # Routine lifecycle details stay in the source logs and can still be shown
    # with [D]iagnostics, but the default view keeps one useful operator event.
    # Raw record plumbing is also hidden: meaningful personal/team records are
    # emitted once through the condensed COMMUNITY -> RANKS operator line.
    if ($Tag -eq "RANKS" -and $Text -match '(?i)\b(PLAYER_ATTACHED|SESSION_STARTED|PLAYER_STARTED|MATCH_CLOCK_STARTED|RECORD_ELIGIBLE|UNRANKED_PERSONAL_ROLLBACK|MATCH_UNRANKED|PLAYER_DISCONNECTED|MATCH_RECORD_ID|MAP_RECORD_OUTSIDE_TOP5|MAP_RECORD_TOP5|PERSONAL_RECORD|TEAM_RECORD_CHAT|PERSONAL_RECORD_CHAT)\b') { return $true }
    if ($Tag -eq "IDENTITY" -and $Text -match '(?i)\bIDENTITY_ATTACHED\b') { return $true }
    if ($Tag -eq "MOD" -and $Text -match '(?i)\bMODERATION_STATE\b') { return $true }
    if ($Tag -eq "LANG" -and $Text -match '(?i)\b(PLAYER_LANGUAGE_ATTACHED|GEOIP_REQUESTED|COUNTRY_ANNOUNCED|LANGUAGE_ASSIGNED)\b') { return $true }
    if ($Tag -eq "COMMUNITY" -and $Text -match '(?i)\b(SPECTATOR_SPAWN_PROMPT|SPECTATOR_WAITING|WELCOME_SENT_HUD|LATE_JOIN_ACTIVE_CONFIRMED|LATE_JOIN_ATTEMPT|NORMAL_DEATH_AFTER_LATE_JOIN|PUBLIC_TIP_CHAT|MAP_ROTATE_COMMAND)\b') { return $true }

    return $false
}

function Test-LineVisible {
    param([string]$Category, [string]$Text)

    if ($script:ActiveFilter -eq "ERROR") { return (Test-CriticalLine $Text) }
    if ($script:ActiveFilter -ne "ALL" -and $Category -ne $script:ActiveFilter) { return $false }
    if (-not [string]::IsNullOrWhiteSpace($script:SearchText)) {
        return $Text.IndexOf($script:SearchText, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    }
    return $true
}

function Get-EffectiveCategory {
    param([string]$Tag, [string]$Category, [string]$Text)
    if ($Text -match '(?i)\b(MUTE|UNMUTE|MUTE_BLOCK|MUTED)\b') { return 'MUTE' }
    if ($Text -match '(?i)\b(BAN|UNBAN|BANNED|BAN_EXPIRED)\b') { return 'BAN' }
    if ($Text -match '(?i)(\[WARN\]|WARNING|STALE|CONFIGURED_NOT_ACTIVE|stopped unexpectedly)') { return 'WARN' }
    return $Category
}


function Format-PauseOperatorMessage {
    param([string]$Text)

    $body = ([string]$Text).Trim()
    $body = $body -replace '^\[[0-9]+(?:\s*ms)?\]\s*', ''
    $body = $body -replace '(?i)\s+\|\s+xuid=[^|]+', ''
    $body = $body -replace '\s+\[[0-9A-Fa-f]{10,}\]', ''

    if ($body -match '(?i)^PAUSE_VOTE_START\s+\|\s+initiator=(?<player>[^|]+)\s+\|\s+required=(?<required>\d+)\s+\|\s+majority=(?<majority>\d+)') {
        return ('VOTE START | pause | {0} | majority {1}/{2} | 20s' -f
            $Matches.player.Trim(), $Matches.majority, $Matches.required)
    }

    if ($body -match '(?i)^RESUME_VOTE_START\s+\|\s+initiator=(?<player>[^|]+)\s+\|\s+required=(?<required>\d+)\s+\|\s+majority=(?<majority>\d+)') {
        return ('VOTE START | resume | {0} | majority {1}/{2} | 15s' -f
            $Matches.player.Trim(), $Matches.majority, $Matches.required)
    }

    if ($body -match '(?i)^VOTE_RESULT\s+\|\s+(?<result>PASSED|FAILED)\s+\|\s+type=(?<type>pause|resume)\s+\|\s+initiator=(?<player>[^|]+)\s+\|\s+yes=(?<yes>\d+/\d+)\s+\|\s+no=(?<no>\d+)\s+\|\s+reason=(?<reason>.+)$') {
        return ('VOTE {0} | {1} | {2} | YES {3} | NO {4} | {5}' -f
            $Matches.result.ToUpperInvariant(),
            $Matches.type.ToLowerInvariant(),
            $Matches.player.Trim(),
            $Matches.yes,
            $Matches.no,
            $Matches.reason.Trim())
    }

    if ($body -match '(?i)^PAUSE_START\s+\|\s+source=(?<source>[^|]+)\s+\|\s+successful_before=(?<used>\d+/\d+)\s+\|\s+active_players=(?<players>\d+)') {
        return ('ACTIVE | max 180s | pauses before {0} | players {1} | {2}' -f
            $Matches.used, $Matches.players, $Matches.source.Trim())
    }

    if ($body -match '(?i)^PAUSE_COUNT\s+\|\s+successful=(?<used>\d+/\d+)') {
        return ('USAGE | successful pauses {0}' -f $Matches.used)
    }

    if ($body -match '(?i)^PAUSE_END\s+\|\s+reason=(?<reason>[^|]+)\s+\|\s+active_players=(?<players>\d+)') {
        return ('RESUMED | {0} | players {1}' -f
            $Matches.reason.Trim(), $Matches.players)
    }

    if ($body -match '(?i)^STATUS\s+\|\s+active=(?<active>true|false)\s+\|\s+remaining=(?<remaining>\d+)\s+\|\s+successful=(?<used>\d+/\d+)\s+\|\s+proposals=(?<proposals>\d+)') {
        return ('STATUS | active={0} | remaining {1}s | pauses {2} | proposals {3}' -f
            $Matches.active.ToLowerInvariant(),
            $Matches.remaining,
            $Matches.used,
            $Matches.proposals)
    }

    return $body
}

function Format-RconOperatorMessage {
    param([string]$Text)

    $body = ([string]$Text).Trim()
    $body = $body -replace '^\[[0-9]{4}-[0-9]{2}-[0-9]{2}\s+[0-9:]+\]\s*', ''

    if ($body -match '(?i)^COMMAND\s+\|\s+(?<command>.+)$') {
        return ('SEND | {0}' -f $Matches.command.Trim())
    }

    return $body
}

function Format-RanksOperatorMessage {
    param([string]$EventName, [string]$Body)

    $cleanBody = ([string]$Body).Trim()
    $cleanBody = $cleanBody -replace '(?i)\s+\|\s+xuids=.*$', ''

    if ($EventName -eq 'TEAM_RECORD_CHAT') {
        $match = [regex]::Match(
            $cleanBody,
            '(?i)^(?<team>[1-4])P record on (?<map>.+?): Round (?<round>\d+) in (?<duration>.+?) \| (?<holders>.+)$'
        )
        if ($match.Success) {
            return ('TEAM RECORD | {0}P | {1} | round {2} | {3} | {4}' -f
                $match.Groups['team'].Value,
                $match.Groups['map'].Value,
                $match.Groups['round'].Value,
                $match.Groups['duration'].Value,
                $match.Groups['holders'].Value
            )
        }
        return 'TEAM RECORD | ' + $cleanBody
    }

    if ($EventName -eq 'PERSONAL_RECORD_CHAT') {
        $match = [regex]::Match(
            $cleanBody,
            '(?i)^(?<player>.+?): Round (?<round>\d+) \(previous: (?<previous>\d+)\)$'
        )
        if ($match.Success) {
            return ('PERSONAL RECORD | {0} | round {1} | previous {2}' -f
                $match.Groups['player'].Value,
                $match.Groups['round'].Value,
                $match.Groups['previous'].Value
            )
        }
        return 'PERSONAL RECORD | ' + $cleanBody
    }

    return $cleanBody
}

function Convert-OperatorLine {
    param([string]$Tag, [string]$Category, [string]$Text)

    if ($Tag -eq 'PAUSE') {
        return [PSCustomObject]@{
            Tag = 'PAUSE'
            Category = 'COMMUNITY'
            Text = Format-PauseOperatorMessage -Text $Text
        }
    }

    if ($Tag -eq 'RCON') {
        return [PSCustomObject]@{
            Tag = 'RCON'
            Category = 'COMMUNITY'
            Text = Format-RconOperatorMessage -Text $Text
        }
    }

    # Ranks writes important announcements to community.log as well as ranks.log.
    # Promote the human-facing copy to a single [RANKS] operator line; the raw
    # persistence details remain available through Diagnostics/source logs.
    if ($Tag -eq 'COMMUNITY') {
        $match = [regex]::Match(
            $Text,
            '(?i)^\[[0-9]+(?:\s*ms)?\]\s+RANKS\s+\|\s+(?<event>TEAM_RECORD_CHAT|PERSONAL_RECORD_CHAT)\s+\|\s+(?<body>.+)$'
        )
        if ($match.Success) {
            return [PSCustomObject]@{
                Tag = 'RANKS'
                Category = 'RANKS'
                Text = Format-RanksOperatorMessage `
                    -EventName $match.Groups['event'].Value.ToUpperInvariant() `
                    -Body $match.Groups['body'].Value
            }
        }
    }

    return [PSCustomObject]@{ Tag=$Tag; Category=$Category; Text=$Text }
}

function Write-TaggedLine {
    param([string]$Tag, [string]$Category, [string]$Text, [string]$Color)

    $Text = Protect-VisibleText -Text $Text

    $converted = Convert-OperatorLine -Tag $Tag -Category $Category -Text $Text
    $Tag = [string]$converted.Tag
    $Category = [string]$converted.Category
    $Text = [string]$converted.Text

    # MODERATION_STATE is informational, not a ban event.
    if ($Tag -eq "BAN" -and $Text -match '(?i)\bMODERATION_STATE\b') {
        $Tag = "MOD"
    }

    $Category = Get-EffectiveCategory -Tag $Tag -Category $Category -Text $Text
    if (-not $script:ShowDiagnostics -and (Test-DiagnosticLine -Tag $Tag -Text $Text)) { return }
    if (-not (Test-LineVisible -Category $Category -Text $Text)) { return }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $displayColor = Get-LineColor -DefaultColor $Color -Text $Text
    Write-Host "[$timestamp][$Tag] " -NoNewline -ForegroundColor $displayColor
    Write-Host $Text -ForegroundColor $displayColor

    $script:VisibleBuffer.Add("[$timestamp][$Tag] $Text") | Out-Null
    if ($script:VisibleBuffer.Count -gt 20000) { $script:VisibleBuffer.RemoveAt(0) }

    if ($script:CriticalSound -and (Test-CriticalLine $Text)) {
        try { [console]::Beep(900, 180) } catch { }
    }
}

function Show-Help {
    Write-Host ""
    Write-Host "Filters: [A]ll [C]hat [J]oin [U]Community [V]ote [K]ick [N]Ban [T]Mute [W]arn" -ForegroundColor Cyan
    Write-Host "         [R]anks [E]E [X]Errors [M]enu [I]dentity [S]torage [G]Language" -ForegroundColor Cyan
    Write-Host "Actions: [F]ind [O]pen logs [P]export [D]iagnostics [B]sound [H]elp [Q]uit" -ForegroundColor Gray
    Write-Host "The Live Console is read-only and never sends server commands." -ForegroundColor DarkGray
    Write-Host ""
}

function Get-AbbreviatedXuid {
    param([string]$Xuid)
    if ([string]::IsNullOrWhiteSpace($Xuid)) { return 'unknown' }
    if ($Xuid.Length -le 10) { return $Xuid }
    return $Xuid.Substring(0, 6) + '...' + $Xuid.Substring($Xuid.Length - 4)
}

function Get-PinteModLogTime {
    param([string]$Line)
    if([string]::IsNullOrWhiteSpace($Line)){return [int64]0}
    $m=[regex]::Match($Line,'^\[(?<time>[0-9]+)(?:\s*ms)?\]')
    if($m.Success){return [int64]$m.Groups['time'].Value}
    return [int64]0
}

function Get-PlayerDashboardState {
    param($Sources)
    $state = @{}
    $maxGetTime = 0
    $maxGetTimeFileWrite = [DateTime]::MinValue

    foreach ($source in $Sources) {
        if (-not (Test-Path -LiteralPath $source.Path)) { continue }
        $sourceItem = Get-Item -LiteralPath $source.Path -ErrorAction SilentlyContinue
        $sourceWrite = if ($sourceItem) { $sourceItem.LastWriteTime } else { [DateTime]::MinValue }
        foreach ($line in (Get-Content -LiteralPath $source.Path -Tail 800 -ErrorAction SilentlyContinue)) {
            $safeLine = Protect-VisibleText ([string]$line)
            $lineGetTime = Get-PinteModLogTime $safeLine
            if ($lineGetTime -gt 0) {
                if ($lineGetTime -ge $maxGetTime) {
                    $maxGetTime = $lineGetTime
                    $maxGetTimeFileWrite = $sourceWrite
                }
            }

            if ($source.Tag -eq 'JOIN' -and $safeLine -match '\[(JOIN|LEAVE)\]\s+(.+?)\s+\|\s+xuid=([^|]+)\|\s+client=([0-9-]+)') {
                $eventName = $matches[1]
                $playerName = $matches[2].Trim()
                $playerXuid = $matches[3].Trim()
                $client = $matches[4]
                if (-not $state.ContainsKey($client)) {
                    $state[$client] = [ordered]@{ Client=$client; Name='unknown'; Xuid=''; Role='pending'; Language='unknown'; Country='unknown'; JoinGetTime=0; Event='LEAVE'; Muted=$false; Banned=$false; Ranked='ranked'; Recent='' }
                }
                $state[$client].Event = $eventName
                $state[$client].Name = $playerName
                $state[$client].Xuid = $playerXuid
                $joinGetTime = Get-PinteModLogTime $safeLine
                if ($joinGetTime -gt 0) { $state[$client].JoinGetTime = $joinGetTime }
                $state[$client].Recent = $eventName.ToLowerInvariant()
            }
            elseif ($source.Tag -eq 'IDENTITY' -and $safeLine -match 'IDENTITY_ATTACHED.*?xuid=([^|]+).*?role=([^|]+)') {
                $xuid = $matches[1].Trim(); $role = $matches[2].Trim()
                foreach ($entry in $state.Values) { if ($entry.Xuid -eq $xuid) { $entry.Role=$role; $entry.Recent='identity' } }
            }
            elseif ($source.Tag -eq 'LANG' -and $safeLine -match 'COUNTRY_ANNOUNCED.*?xuid=([^|]+).*?country_code=([^|]+).*?language=([^|]+)') {
                $xuid=$matches[1].Trim(); $country=$matches[2].Trim(); $language=$matches[3].Trim()
                foreach ($entry in $state.Values) { if ($entry.Xuid -eq $xuid) { $entry.Country=$country; $entry.Language=$language; $entry.Recent='country' } }
            }
            elseif ($source.Tag -eq 'LANG' -and $safeLine -match '(?:PLAYER_LANGUAGE_ATTACHED|LANGUAGE_ASSIGNED|LANGUAGE_CHANGED).*?xuid=([^|]+).*?language=([^|]+)') {
                $xuid=$matches[1].Trim(); $language=$matches[2].Trim()
                foreach ($entry in $state.Values) { if ($entry.Xuid -eq $xuid) { $entry.Language=$language; $entry.Recent='language' } }
            }
            elseif ($safeLine -match '(?i)\b(MUTE|UNMUTE)\b.*?target_xuid=([^|]+)') {
                $actionName=$matches[1].ToUpperInvariant(); $xuid=$matches[2].Trim(); $isMuted=($actionName -eq 'MUTE')
                foreach ($entry in $state.Values) { if ($entry.Xuid -eq $xuid) { $entry.Muted=$isMuted; $entry.Recent=$actionName.ToLowerInvariant() } }
            }
            elseif ($source.Tag -eq 'RANKS' -and $safeLine -match '(?i)MATCH_UNRANKED') {
                foreach ($entry in $state.Values) { $entry.Ranked='unranked' }
            }
        }
    }

    $effectiveGetTime = $maxGetTime
    if ($maxGetTime -gt 0 -and $maxGetTimeFileWrite -ne [DateTime]::MinValue) {
        $elapsed = [Math]::Max(0, ((Get-Date) - $maxGetTimeFileWrite).TotalMilliseconds)
        $effectiveGetTime += [int64]$elapsed
    }

    $muteRoot = Join-Path $script:DataRoot 'moderation\mutes'
    $banRoot = Join-Path $script:DataRoot 'bans\active'
    foreach ($entry in $state.Values) {
        if ($entry.Xuid) {
            $entry.Muted = Test-Path -LiteralPath (Join-Path $muteRoot "$($entry.Xuid).json")
            $entry.Banned = Test-Path -LiteralPath (Join-Path $banRoot "$($entry.Xuid).json")
        }
        $entry.Presence = if ($entry.JoinGetTime -gt 0 -and $effectiveGetTime -ge $entry.JoinGetTime) {
            [TimeSpan]::FromMilliseconds($effectiveGetTime - $entry.JoinGetTime).ToString('hh\:mm\:ss')
        } else { 'unknown' }
    }
    return @($state.Values | Where-Object { $_.Event -eq 'JOIN' } | Sort-Object {[int]$_.Client})
}

function Show-PlayerDashboard {
    param($Sources, [switch]$Force)
    $players = @(Get-PlayerDashboardState -Sources $Sources)
    $now = Get-Date

    $activeKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach($entry in $players){
        $key = if($entry.Xuid){[string]$entry.Xuid}else{[string]$entry.Client}
        [void]$activeKeys.Add($key)

        # Give identity + GeoIP a short window to converge so one connection
        # produces one useful dashboard row instead of role/country/language redraws.
        $needsEnrichment = (
            $entry.Role -eq 'pending' -or
            $entry.Language -eq 'unknown' -or
            $entry.Country -eq 'unknown'
        )
        if($needsEnrichment -and -not $script:PendingDashboardSince.ContainsKey($key)){
            $script:PendingDashboardSince[$key]=$now
        }
        elseif(-not $needsEnrichment){
            [void]$script:PendingDashboardSince.Remove($key)
        }
    }
    foreach($key in @($script:PendingDashboardSince.Keys)){
        if(-not $activeKeys.Contains([string]$key)){[void]$script:PendingDashboardSince.Remove($key)}
    }

    if(-not $Force){
        foreach($entry in $players){
            $needsEnrichment = (
                $entry.Role -eq 'pending' -or
                $entry.Language -eq 'unknown' -or
                $entry.Country -eq 'unknown'
            )
            if(-not $needsEnrichment){continue}
            $key = if($entry.Xuid){[string]$entry.Xuid}else{[string]$entry.Client}
            if($script:PendingDashboardSince.ContainsKey($key) -and ($now-$script:PendingDashboardSince[$key]).TotalSeconds -lt 8){return}
        }
    }

    # Presence and internal "Recent" data continue to update, but neither one
    # forces a redraw. Only operator-relevant state changes do.
    $signature = ($players | ForEach-Object { "$($_.Client)|$($_.Xuid)|$($_.Role)|$($_.Language)|$($_.Country)|$($_.Muted)|$($_.Banned)|$($_.Ranked)" }) -join ';'
    if (-not $Force -and $signature -eq $script:LastDashboardSignature) { return }
    $script:LastDashboardSignature = $signature
    $script:LastDashboardRender = $now

    Write-Host ''
    if ($players.Count -eq 0) {
        Write-Host '[PLAYERS] none' -ForegroundColor DarkGray
        return
    }

    Write-Host '----- PLAYERS -----' -ForegroundColor DarkCyan
    foreach ($entry in $players) {
        $status = @()
        if ($entry.Muted) { $status += 'MUTED' }
        if ($entry.Banned) { $status += 'BANNED' }
        if ($status.Count -eq 0) { $status += 'OK' }
        $displayRole = if($entry.Role -eq 'pending'){'unknown'}else{$entry.Role}
        $locale = if($entry.Country -ne 'unknown' -or $entry.Language -ne 'unknown') {
            "$($entry.Country)/$($entry.Language)"
        } else {
            'unknown'
        }
        Write-Host (" #{0} {1} | XUID={2} | {3} | {4} | {5} | {6} | {7}" -f
            $entry.Client,
            $entry.Name,
            (Get-AbbreviatedXuid $entry.Xuid),
            $displayRole,
            $locale,
            ($status -join ','),
            $entry.Ranked,
            $entry.Presence
        ) -ForegroundColor DarkCyan
    }
}

function Show-StartupSummary {
    param($Manifest, [string]$SessionRoot, $Sources)

    Clear-Host
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host " PinteMod v2.1.1 - Live Console" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkCyan
    if ($script:RemoteReadOnly) {
        Write-Host " Mode        : REMOTE READ-ONLY (LAN)" -ForegroundColor Green
        Write-Host " Data share  : $script:DataRoot" -ForegroundColor Gray
    } else {
        Write-Host " Server root : $script:ServerRoot" -ForegroundColor Gray
    }
    Write-Host " Map         : $($Manifest.map)" -ForegroundColor Gray
    Write-Host " Session     : $($Manifest.session_id)" -ForegroundColor Gray
    Write-Host " Log folder  : $SessionRoot" -ForegroundColor Gray

    $available = @($Sources | Where-Object { Test-Path -LiteralPath $_.Path }).Count
    Write-Host " Sources     : $available/$($Sources.Count) currently created" -ForegroundColor Gray

    $players = @(Get-PlayerDashboardState -Sources $Sources)
    Write-Host " Players     : $($players.Count) inferred from session logs" -ForegroundColor Gray

    $detectedModules = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($source in $Sources) {
        if (-not (Test-Path -LiteralPath $source.Path)) { continue }
        foreach ($line in (Get-Content -LiteralPath $source.Path -Tail 80 -ErrorAction SilentlyContinue)) {
            if ($line -match '(?i)(MODULE_LOADED|\bloaded\b)') { [void]$detectedModules.Add($source.Tag) }
        }
    }
    if ($detectedModules.Count -gt 0) {
        $moduleList = @($detectedModules | Sort-Object) -join ', '
        Write-Host " Modules/logs: $moduleList" -ForegroundColor Gray
    }

    Show-PlayerDashboard -Sources $Sources -Force
    Show-Help
}

function Archive-Session {
    param([string]$SessionRoot, [string]$SessionId)
    if ($script:RemoteReadOnly) { return }
    if (-not (Test-Path -LiteralPath $SessionRoot) -or $SessionId -eq "waiting_for_server") { return }

    try { $day = (Get-Item -LiteralPath $SessionRoot -ErrorAction Stop).LastWriteTime.ToString("yyyy-MM-dd") }
    catch { $day = Get-Date -Format "yyyy-MM-dd" }
    $archiveRoot = Join-Path (Join-Path $script:LogRoot "archive") $day
    Ensure-Directory $archiveRoot
    $destination = Join-Path $archiveRoot $SessionId
    if (-not (Test-Path -LiteralPath $destination)) {
        try { Copy-Item -LiteralPath $SessionRoot -Destination $destination -Recurse -Force -ErrorAction Stop }
        catch { Write-Host "[WARN] Session archive failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
}

function Archive-CompletedSessions {
    param([string]$CurrentSessionId)
    if ($script:RemoteReadOnly) { return }

    $sessionsRoot = Join-Path $script:LogRoot "sessions"
    if (-not (Test-Path -LiteralPath $sessionsRoot)) { return }

    foreach ($directory in (Get-ChildItem -LiteralPath $sessionsRoot -Directory -ErrorAction SilentlyContinue)) {
        if ($directory.Name -eq $CurrentSessionId) { continue }
        if ($directory.Name -like "bootstrap_*") { continue }
        Archive-Session -SessionRoot $directory.FullName -SessionId $directory.Name
    }
}

function Export-VisibleView {
    $exports = Join-Path $PSScriptRoot "exports"
    Ensure-Directory $exports
    $path = Join-Path $exports ("PinteMod_LiveConsole_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    $header = @(
        "PinteMod v2.1.1 Live Console export",
        "Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Source: $(if ($script:RemoteReadOnly) { $script:DataRoot } else { $script:ServerRoot })",
        "Session: $($script:Manifest.session_id)",
        "Map: $($script:Manifest.map)",
        "Filter: $script:ActiveFilter",
        "Search: $script:SearchText",
        "Diagnostics: $script:ShowDiagnostics",
        ""
    )
    Set-Content -LiteralPath $path -Value ($header + $script:VisibleBuffer) -Encoding UTF8
    Write-Host "Exported: $path" -ForegroundColor Green
}

function Reset-SourceStates {
    param($Sources, [switch]$TailExisting)

    $script:FileStates = @{}

    foreach ($source in $Sources) {
        $position = [int64]0

        if (Test-Path -LiteralPath $source.Path) {
            if ($TailExisting) {
                foreach ($line in (Get-Content -LiteralPath $source.Path -Tail $InitialLines -ErrorAction SilentlyContinue)) {
                    Write-TaggedLine -Tag $source.Tag -Category $source.Category -Text ([string]$line) -Color $source.Color
                }
            }

            try { $position = [int64](Get-Item -LiteralPath $source.Path -ErrorAction Stop).Length }
            catch { $position = [int64]0 }
        }

        $script:FileStates[$source.Path] = [PSCustomObject]@{
            Position = $position
            Remainder = ""
        }
    }
}

function Read-NewSourceLines {
    param($Source)

    if (-not (Test-Path -LiteralPath $Source.Path)) { return }

    if (-not $script:FileStates.ContainsKey($Source.Path)) {
        $script:FileStates[$Source.Path] = [PSCustomObject]@{
            Position = [int64]0
            Remainder = ""
        }
    }

    $state = $script:FileStates[$Source.Path]

    try { $length = [int64](Get-Item -LiteralPath $Source.Path -ErrorAction Stop).Length }
    catch { return }

    # Rotation or rewrite truncated the active file.
    if ($length -lt [int64]$state.Position) {
        $state.Position = [int64]0
        $state.Remainder = ""
    }

    if ($length -eq [int64]$state.Position) { return }

    $stream = $null
    $reader = $null

    try {
        $stream = [System.IO.File]::Open(
            $Source.Path,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        [void]$stream.Seek([int64]$state.Position, [System.IO.SeekOrigin]::Begin)
        $encoding = [System.Text.UTF8Encoding]::new($false)
        $reader = [System.IO.StreamReader]::new(
            $stream,
            $encoding,
            $true,
            4096,
            $true
        )
        $chunk = $reader.ReadToEnd()
        $state.Position = [int64]$stream.Length
    }
    catch {
        Write-Host "[WARN] Cannot read $($Source.Path): $($_.Exception.Message)" -ForegroundColor Yellow
        return
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($stream) { $stream.Dispose() }
    }

    if ([string]::IsNullOrEmpty($chunk)) { return }

    $combined = [string]$state.Remainder + $chunk
    $parts = [System.Text.RegularExpressions.Regex]::Split($combined, "`r?`n")
    $hasTrailingNewline = $combined.EndsWith("`n") -or $combined.EndsWith("`r")

    if ($hasTrailingNewline) {
        $state.Remainder = ""
        $completeCount = $parts.Count
    }
    else {
        $state.Remainder = [string]$parts[$parts.Count - 1]
        $completeCount = $parts.Count - 1
    }

    for ($index = 0; $index -lt $completeCount; $index++) {
        $line = [string]$parts[$index]
        if ($line.Length -eq 0) { continue }
        Write-TaggedLine -Tag $Source.Tag -Category $Source.Category -Text $line -Color $Source.Color
    }
}

function Process-Key {
    param([System.ConsoleKeyInfo]$Key)
    switch ($Key.Key) {
        "A" { $script:ActiveFilter = "ALL" }
        "C" { $script:ActiveFilter = "CHAT" }
        "J" { $script:ActiveFilter = "JOIN" }
        "U" { $script:ActiveFilter = "COMMUNITY" }
        "V" { $script:ActiveFilter = "VOTE" }
        "K" { $script:ActiveFilter = "KICK" }
        "N" { $script:ActiveFilter = "BAN" }
        "T" { $script:ActiveFilter = "MUTE" }
        "W" { $script:ActiveFilter = "WARN" }
        "R" { $script:ActiveFilter = "RANKS" }
        "E" { $script:ActiveFilter = "EE" }
        "X" { $script:ActiveFilter = "ERROR" }
        "M" { $script:ActiveFilter = "MENU" }
        "I" { $script:ActiveFilter = "IDENTITY" }
        "S" { $script:ActiveFilter = "STORAGE" }
        "G" { $script:ActiveFilter = "LANGUAGE" }
        "F" {
            Write-Host ""
            $script:SearchText = Read-Host "Search text (empty clears)"
        }
        "O" { Start-Process explorer.exe -ArgumentList ('"{0}"' -f $script:SessionRoot) }
        "P" { Export-VisibleView }
        "D" {
            $script:ShowDiagnostics = -not $script:ShowDiagnostics
            Write-Host "Diagnostic lines: $script:ShowDiagnostics" -ForegroundColor Yellow
        }
        "B" {
            $script:CriticalSound = -not $script:CriticalSound
            Write-Host "Critical sound: $script:CriticalSound" -ForegroundColor Yellow
        }
        "H" { Show-Help }
        "Q" { $script:Quit = $true; return }
        default { return }
    }
    if ($Key.Key -in @("A","C","J","U","V","K","N","T","W","R","E","X","M","I","S","G")) {
        Write-Host "Filter: $script:ActiveFilter | Search: $script:SearchText" -ForegroundColor DarkGray
    }
}

$script:RemoteReadOnly = -not [string]::IsNullOrWhiteSpace($RemoteDataRoot)
if ($script:RemoteReadOnly) {
    $script:ServerRoot = ''
    $script:DataRoot = Resolve-RemoteDataRoot -RequestedRoot $RemoteDataRoot
    $script:LogRoot = Join-Path $script:DataRoot 'logs'
    # Remote mode never writes to the server share. The server-side tools keep
    # their own health state; this viewer is purely an operator-side reader.
    $script:HealthRoot = ''
    $script:HeartbeatPath = $null
} else {
    $script:ServerRoot = Resolve-ServerRoot -RequestedRoot $ServerRoot
    $script:DataRoot = Join-Path $script:ServerRoot 'boiii\scriptdata\pintemod'
    $script:LogRoot = Join-Path $script:DataRoot 'logs'
    $script:HealthRoot = Join-Path $script:DataRoot 'health'
    $script:HeartbeatPath = Join-Path $script:HealthRoot 'live_console.json'
}
$script:HeartbeatSequence = 0
$script:LastDashboardSignature = ''
$script:LastDashboardRender = [DateTime]::MinValue
$script:PendingDashboardSince = @{}
if (-not $script:RemoteReadOnly) {
    Ensure-Directory $script:HealthRoot
    Ensure-Directory $script:LogRoot
    Ensure-Directory (Join-Path $script:LogRoot "sessions")
}

$script:ActiveFilter = "ALL"
$script:SearchText = ""
$script:ShowDiagnostics = $false
$script:CriticalSound = [bool]$EnableCriticalSound
$script:VisibleBuffer = New-Object 'System.Collections.Generic.List[string]'
$script:Quit = $false
$script:Manifest = Read-SessionManifest -Root $script:LogRoot
$script:SessionRoot = Get-SessionRoot -Manifest $script:Manifest -Root $script:LogRoot
$script:Sources = Get-SourceDefinitions -SessionRoot $script:SessionRoot
$script:FileStates = @{}
Archive-CompletedSessions -CurrentSessionId ([string]$script:Manifest.session_id)

if ($script:RemoteReadOnly) {
    $Host.UI.RawUI.WindowTitle = "PinteMod v2.1.1 - Live Console (REMOTE LAN)"
}

Show-StartupSummary -Manifest $script:Manifest -SessionRoot $script:SessionRoot -Sources $script:Sources
Reset-SourceStates -Sources $script:Sources -TailExisting
Write-Host "----- LIVE OUTPUT -----" -ForegroundColor DarkGray

$lastManifestCheck = Get-Date
$lastHeartbeat = [DateTime]::MinValue
$lastDashboard = [DateTime]::MinValue
try { Write-LiveHeartbeat -State 'running' } catch { Write-Warning ('Heartbeat write failed: ' + $_.Exception.Message) }

try {
    while (-not $script:Quit) {
        while ([console]::KeyAvailable) {
            Process-Key -Key ([console]::ReadKey($true))
        }

        if (((Get-Date) - $lastManifestCheck).TotalSeconds -ge 1) {
            $lastManifestCheck = Get-Date
            $newManifest = Read-SessionManifest -Root $script:LogRoot
            if ([string]$newManifest.session_id -ne [string]$script:Manifest.session_id) {
                Archive-Session -SessionRoot $script:SessionRoot -SessionId ([string]$script:Manifest.session_id)
                $script:Manifest = $newManifest
                $script:SessionRoot = Get-SessionRoot -Manifest $script:Manifest -Root $script:LogRoot
                $script:Sources = Get-SourceDefinitions -SessionRoot $script:SessionRoot
                $script:LastDashboardSignature = ''
                $script:LastDashboardRender = [DateTime]::MinValue
                $script:PendingDashboardSince = @{}
                Write-Host "Session: $($script:Manifest.session_id) | map=$($script:Manifest.map)" -ForegroundColor Cyan
                Reset-SourceStates -Sources $script:Sources
            }
        }

        foreach ($source in $script:Sources) {
            Read-NewSourceLines -Source $source
        }

        if (((Get-Date) - $lastDashboard).TotalSeconds -ge 5) {
            $lastDashboard = Get-Date
            Show-PlayerDashboard -Sources $script:Sources
        }
        if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge 2) {
            $lastHeartbeat = Get-Date
            try { Write-LiveHeartbeat -State 'running' } catch { Write-Warning ('Heartbeat write failed: ' + $_.Exception.Message) }
        }

        Start-Sleep -Milliseconds 250
    }
}
finally {
    try { Write-LiveHeartbeat -State 'stopped' } catch { }
    Archive-Session -SessionRoot $script:SessionRoot -SessionId ([string]$script:Manifest.session_id)
    Write-Host "PinteMod Live Console stopped." -ForegroundColor DarkGray
    if ($mutex) {
        try { if ($mutexOwned) { $mutex.ReleaseMutex() | Out-Null } } catch { }
        $mutex.Dispose()
    }
}
