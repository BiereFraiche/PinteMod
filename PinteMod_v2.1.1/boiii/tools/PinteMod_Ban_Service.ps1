param(
    [string]$ServerRoot = "",
    [int]$PollIntervalMs = 250
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "PinteMod v2.1.1 - Ban Service"

$mutex = New-Object System.Threading.Mutex($false, "Global\PinteMod_v2_1_BanService")
$mutexOwned = $false
try {
    $mutexOwned = $mutex.WaitOne(0, $false)
}
catch [System.Threading.AbandonedMutexException] {
    $mutexOwned = $true
}
if (-not $mutexOwned) {
    $mutex.Dispose()
    throw "PinteMod Ban Service is already running."
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

    foreach ($seed in @($RequestedRoot, $PSScriptRoot, (Get-Location).Path) | Select-Object -Unique) {
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

function Write-JsonAtomic {
    param([string]$Path, $Value)
    $directory = Split-Path -Parent $Path
    Ensure-Directory $directory
    $temp = "$Path.tmp"
    $json = $Value | ConvertTo-Json -Depth 10
    Write-Utf8NoBom -Path $temp -Content $json
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Write-HealthHeartbeat {
    param(
        [string]$State = "running",
        [string]$LastErrorCode = "",
        [int]$ActiveBans = 0
    )

    if (-not $script:HeartbeatPath) { return }
    $script:HeartbeatSequence++
    $heartbeat = [ordered]@{
        schema_version = 1
        tool = "ban_service"
        version = "2.1.1"
        state = $State
        sequence = $script:HeartbeatSequence
        updated_utc = [DateTime]::UtcNow.ToString("o")
        active_bans = $ActiveBans
        last_error_code = $LastErrorCode
        privacy = "BOIII_XUID only; no IP or secret"
    }
    Write-JsonAtomic -Path $script:HeartbeatPath -Value $heartbeat
}

function Get-ModerationHistoryPath {
    param([string]$Xuid)
    return Join-Path $script:ModerationHistoryRoot "$Xuid.json"
}

function Read-ModerationHistory {
    param([string]$Xuid, [string]$Display)

    $path = Get-ModerationHistoryPath -Xuid $Xuid
    if (Test-Path -LiteralPath $path) {
        try { return Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
        catch { }
    }

    return [pscustomobject]@{
        schema_version = 1
        identity_kind = "BOIII_XUID"
        xuid = $Xuid
        last_display_name = $Display
        kicks = 0
        mutes = 0
        temporary_bans = 0
        permanent_bans = 0
        unbans = 0
        last_action = "none"
        last_reason = ""
        last_actor_xuid = "server"
        last_updated_utc = ""
    }
}

function Update-ModerationHistory {
    param(
        [string]$Xuid,
        [string]$Display,
        [string]$Action,
        [string]$Reason,
        [string]$ActorXuid
    )

    $history = Read-ModerationHistory -Xuid $Xuid -Display $Display
    foreach ($property in @('kicks','mutes','temporary_bans','permanent_bans','unbans')) {
        if (-not $history.PSObject.Properties[$property]) {
            $history | Add-Member -NotePropertyName $property -NotePropertyValue 0 -Force
        }
    }

    switch ($Action) {
        'temporary_ban' { $history.temporary_bans = [int]$history.temporary_bans + 1 }
        'permanent_ban' { $history.permanent_bans = [int]$history.permanent_bans + 1 }
        'unban' { $history.unbans = [int]$history.unbans + 1 }
    }

    $history.schema_version = 1
    $history.identity_kind = 'BOIII_XUID'
    $history.xuid = $Xuid
    $history.last_display_name = $Display
    $history.last_action = $Action
    $history.last_reason = (($Reason -replace "[\r\n]", ' ').Trim())
    $history.last_actor_xuid = if ($ActorXuid) { $ActorXuid } else { 'server' }
    if ($history.PSObject.Properties['last_gettime']) { $history.last_gettime = 0 }
    if (-not $history.PSObject.Properties['last_updated_utc']) {
        $history | Add-Member -NotePropertyName last_updated_utc -NotePropertyValue '' -Force
    }
    $history.last_updated_utc = [DateTime]::UtcNow.ToString('o')

    Write-JsonAtomic -Path (Get-ModerationHistoryPath -Xuid $Xuid) -Value $history
}

function Normalize-Xuid {
    param([string]$Xuid)
    if ([string]::IsNullOrWhiteSpace($Xuid)) { return "" }
    $value = $Xuid.Trim().ToLowerInvariant()
    if ($value.StartsWith("0x")) { $value = $value.Substring(2) }
    if ($value -notmatch '^[0-9a-f]{12,32}$') { return "" }
    return $value
}

function Get-ProtectedOwnerXuids {
    $values = New-Object System.Collections.Generic.List[string]
    $configPath = Join-Path $script:BoiiiRoot "custom_scripts\ezz_admin_config.gsc"
    if (Test-Path -LiteralPath $configPath) {
        try {
            $content = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop
            foreach ($match in [regex]::Matches($content, 'ezz_owner_xuids\s*\[[^\]]+\]\s*=\s*"([0-9a-fA-F]{12,32})"')) {
                $xuid = Normalize-Xuid $match.Groups[1].Value
                if ($xuid -and -not $values.Contains($xuid)) { $values.Add($xuid) | Out-Null }
            }
        }
        catch { }
    }
    return @($values)
}

function Read-Database {
    if (-not (Test-Path -LiteralPath $script:DatabasePath)) {
        return [PSCustomObject]@{
            schema_version = 1
            updated_utc = [DateTime]::UtcNow.ToString("o")
            bans = @()
        }
    }

    try {
        $db = Get-Content -LiteralPath $script:DatabasePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if (-not $db.bans) { $db | Add-Member -NotePropertyName bans -NotePropertyValue @() -Force }
        return $db
    }
    catch {
        $backup = "$($script:DatabasePath).corrupt_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
        Copy-Item -LiteralPath $script:DatabasePath -Destination $backup -Force -ErrorAction SilentlyContinue
        return [PSCustomObject]@{
            schema_version = 1
            updated_utc = [DateTime]::UtcNow.ToString("o")
            bans = @()
        }
    }
}

function Save-Database {
    param($Database)
    $Database.schema_version = 1
    $Database.updated_utc = [DateTime]::UtcNow.ToString("o")
    Write-JsonAtomic -Path $script:DatabasePath -Value $Database
}

function Parse-Duration {
    param([string]$Token)

    $text = ([string]$Token).Trim().ToLowerInvariant()
    if ($text -in @("perm", "permanent", "forever")) {
        return [PSCustomObject]@{ Valid=$true; Normalized="perm"; ExpiresUtc=$null }
    }

    if ($text -notmatch '^([1-9][0-9]{0,5})(m|h|d|w)$') {
        return [PSCustomObject]@{ Valid=$false; Normalized=$text; ExpiresUtc=$null }
    }

    $amount = [int]$matches[1]
    $unit = $matches[2]
    $now = [DateTime]::UtcNow
    switch ($unit) {
        "m" { $expires = $now.AddMinutes($amount) }
        "h" { $expires = $now.AddHours($amount) }
        "d" { $expires = $now.AddDays($amount) }
        "w" { $expires = $now.AddDays($amount * 7) }
    }

    return [PSCustomObject]@{ Valid=$true; Normalized="$amount$unit"; ExpiresUtc=$expires }
}

function Get-ActiveEntries {
    param($Database)
    return @($Database.bans | Where-Object { $_.active -eq $true })
}

function Find-ActiveBan {
    param($Database, [string]$Xuid)
    return @($Database.bans | Where-Object { $_.active -eq $true -and (Normalize-Xuid $_.xuid) -eq $Xuid } | Select-Object -Last 1)
}

function Set-BanInactive {
    param($Database, [string]$Xuid, [string]$Reason)
    foreach ($entry in @($Database.bans)) {
        if ($entry.active -eq $true -and (Normalize-Xuid $_.xuid) -eq $Xuid) {
            $entry.active = $false
            $entry.closed_utc = [DateTime]::UtcNow.ToString("o")
            $entry.closed_reason = $Reason
        }
    }
}

function Get-CurrentModerationLog {
    $manifestPath = Join-Path $script:LogRoot "current_session.json"
    if (-not (Test-Path -LiteralPath $manifestPath)) { return $null }
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if (-not $manifest.session_id) { return $null }
        $sessionRoot = Join-Path (Join-Path $script:LogRoot "sessions") ([string]$manifest.session_id)
        Ensure-Directory $sessionRoot
        return Join-Path $sessionRoot "moderation.log"
    }
    catch { return $null }
}

function Write-ModerationEvent {
    param([string]$Event, [string]$Details)
    $line = "[$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))] $Event"
    if (-not [string]::IsNullOrWhiteSpace($Details)) { $line += " | $Details" }

    $path = Get-CurrentModerationLog
    if (-not $path) { $path = Join-Path $script:BanRoot "service.log" }
    Ensure-Directory (Split-Path -Parent $path)
    [System.IO.File]::AppendAllText($path, $line + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

function Write-Response {
    param([string]$RequestId, [string]$Status, [string]$Message, [string]$TargetXuid)
    $response = [PSCustomObject]@{
        schema_version = 1
        request_id = $RequestId
        status = $Status
        message = $Message
        target_xuid = $TargetXuid
        processed_utc = [DateTime]::UtcNow.ToString("o")
    }
    Write-JsonAtomic -Path (Join-Path $script:ResponseRoot "$RequestId.json") -Value $response
}

function Write-ActiveMarker {
    param($Entry)
    $marker = [PSCustomObject]@{
        schema_version = 1
        xuid = [string]$Entry.xuid
        display = [string]$Entry.display
        duration = [string]$Entry.duration
        created_utc = [string]$Entry.created_utc
        expires_utc = if ($Entry.expires_utc) { [string]$Entry.expires_utc } else { "never" }
        reason = [string]$Entry.reason
        actor = [string]$Entry.actor
        active = $true
    }
    Write-JsonAtomic -Path (Join-Path $script:ActiveRoot "$($Entry.xuid).json") -Value $marker
}

function Remove-ActiveMarker {
    param([string]$Xuid)
    Remove-Item -LiteralPath (Join-Path $script:ActiveRoot "$Xuid.json") -Force -ErrorAction SilentlyContinue
}

function Write-Summary {
    param($Database)
    $active = @(Get-ActiveEntries $Database)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Active bans: $($active.Count)") | Out-Null
    foreach ($entry in $active | Sort-Object created_utc) {
        $expires = if ($entry.expires_utc) { [string]$entry.expires_utc } else { "never" }
        $display = if ($entry.display) { [string]$entry.display } else { "unknown" }
        $lines.Add("$display | xuid=$($entry.xuid) | duration=$($entry.duration) | expires_utc=$expires | reason=$($entry.reason)") | Out-Null
    }
    Write-Utf8NoBom -Path $script:SummaryPath -Content (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
}

function Write-ServiceStatus {
    param($Database)
    $status = [PSCustomObject]@{
        schema_version = 1
        version = "2.1.1"
        running = $true
        updated_utc = [DateTime]::UtcNow.ToString("o")
        active_bans = @(Get-ActiveEntries $Database).Count
        privacy = "BOIII_XUID only; no IP persisted"
    }
    Write-JsonAtomic -Path $script:StatusPath -Value $status
}

function Cleanup-ExpiredBans {
    param($Database)
    $changed = $false
    $now = [DateTime]::UtcNow
    foreach ($entry in @($Database.bans)) {
        if ($entry.active -ne $true -or -not $entry.expires_utc) { continue }
        $expires = [DateTime]::MinValue
        if ([DateTime]::TryParse([string]$entry.expires_utc, [ref]$expires) -and $expires.ToUniversalTime() -le $now) {
            $entry.active = $false
            $entry.closed_utc = $now.ToString("o")
            $entry.closed_reason = "expired"
            $expiredXuid = Normalize-Xuid ([string]$entry.xuid)
            Remove-ActiveMarker -Xuid $expiredXuid
            Write-ModerationEvent -Event "BAN_EXPIRED" -Details "player=$($entry.display) | xuid=$($entry.xuid)"
            if ($expiredXuid) {
                Update-ModerationHistory -Xuid $expiredXuid -Display ([string]$entry.display) -Action 'ban_expired' -Reason 'expired' -ActorXuid 'server'
            }
            $changed = $true
        }
    }
    return $changed
}

function Rebuild-ActiveMarkers {
    param($Database)
    Get-ChildItem -LiteralPath $script:ActiveRoot -Filter '*.json' -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    foreach ($entry in @(Get-ActiveEntries $Database)) {
        Write-ActiveMarker -Entry $entry
    }
}

function Process-Request {
    param([System.IO.FileInfo]$File, $Database)

    $requestId = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
    try {
        $request = Get-Content -LiteralPath $File.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($request.request_id) { $requestId = [string]$request.request_id }
        $action = ([string]$request.action).Trim().ToLowerInvariant()
        $xuid = Normalize-Xuid ([string]$request.target_xuid)
        if (-not $xuid) { throw "Invalid target XUID" }

        $actorRole = [int]$request.actor_role
        $targetRole = [int]$request.target_role
        if ($actorRole -lt 3) { throw "Admin role required" }

        if ($action -eq "ban") {
            if ($xuid -in $script:ProtectedOwnerXuids) { throw "Bootstrap Owner is protected" }
            if ($targetRole -ge $actorRole) { throw "Cannot ban an equal or higher role" }
            $duration = Parse-Duration ([string]$request.duration)
            if (-not $duration.Valid) { throw "Invalid duration; use 30m, 2h, 7d, 4w or perm" }

            Set-BanInactive -Database $Database -Xuid $xuid -Reason "replaced"
            Remove-ActiveMarker -Xuid $xuid

            $safeReason = ([string]$request.reason -replace "[\r\n]", " ").Trim()
            if ([string]::IsNullOrWhiteSpace($safeReason)) { $safeReason = "No reason provided" }
            if ($safeReason.Length -gt 120) { $safeReason = $safeReason.Substring(0, 120) }

            $entry = [PSCustomObject]@{
                xuid = $xuid
                display = [string]$request.target_display
                duration = $duration.Normalized
                created_utc = [DateTime]::UtcNow.ToString("o")
                expires_utc = if ($duration.ExpiresUtc) { $duration.ExpiresUtc.ToString("o") } else { $null }
                reason = $safeReason
                actor = [string]$request.actor
                actor_xuid = Normalize-Xuid ([string]$request.actor_xuid)
                actor_role = [int]$request.actor_role
                active = $true
                closed_utc = $null
                closed_reason = $null
            }
            $Database.bans = @($Database.bans) + @($entry)
            Write-ActiveMarker -Entry $entry
            Save-Database $Database
            Write-Summary $Database
            Write-ModerationEvent -Event "PLAYER_BANNED" -Details "player=$($entry.display) | xuid=$xuid | duration=$($entry.duration) | expires_utc=$(if ($entry.expires_utc) {$entry.expires_utc} else {'never'}) | actor=$($entry.actor) | reason=$($entry.reason)"
            $historyAction = if ($entry.duration -eq 'perm') { 'permanent_ban' } else { 'temporary_ban' }
            Update-ModerationHistory -Xuid $xuid -Display ([string]$entry.display) -Action $historyAction -Reason ([string]$entry.reason) -ActorXuid ([string]$entry.actor_xuid)
            Write-Response -RequestId $requestId -Status "ok" -Message "Ban applied to $($entry.display) ($($entry.duration))" -TargetXuid $xuid
        }
        elseif ($action -eq "unban") {
            $existing = @(Find-ActiveBan -Database $Database -Xuid $xuid)
            if ($existing.Count -eq 0) {
                Write-Response -RequestId $requestId -Status "error" -Message "No active ban for $xuid" -TargetXuid $xuid
            }
            else {
                Set-BanInactive -Database $Database -Xuid $xuid -Reason "manual-unban"
                Remove-ActiveMarker -Xuid $xuid
                Save-Database $Database
                Write-Summary $Database
                Write-ModerationEvent -Event "PLAYER_UNBANNED" -Details "xuid=$xuid | actor=$($request.actor)"
                Update-ModerationHistory -Xuid $xuid -Display ([string]$request.target_display) -Action 'unban' -Reason 'manual-unban' -ActorXuid (Normalize-Xuid ([string]$request.actor_xuid))
                Write-Response -RequestId $requestId -Status "ok" -Message "Ban removed for $xuid" -TargetXuid $xuid
            }
        }
        else {
            throw "Unsupported action: $action"
        }
    }
    catch {
        Write-Response -RequestId $requestId -Status "error" -Message $_.Exception.Message -TargetXuid ""
        Write-ModerationEvent -Event "BAN_REQUEST_REJECTED" -Details "request=$requestId | error=$($_.Exception.Message)"
    }
    finally {
        Remove-Item -LiteralPath $File.FullName -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath "$($File.FullName).tmp" -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath "$($File.FullName).bak" -Force -ErrorAction SilentlyContinue
    }
}

$script:ServerRoot = Resolve-ServerRoot -RequestedRoot $ServerRoot
$script:BoiiiRoot = Join-Path $script:ServerRoot "boiii"
$script:BanRoot = Join-Path $script:BoiiiRoot "scriptdata\pintemod\bans"
$script:RequestRoot = Join-Path $script:BanRoot "requests"
$script:ResponseRoot = Join-Path $script:BanRoot "responses"
$script:ActiveRoot = Join-Path $script:BanRoot "active"
$script:DatabasePath = Join-Path $script:BanRoot "bans.json"
$script:SummaryPath = Join-Path $script:BanRoot "bans_summary.txt"
$script:StatusPath = Join-Path $script:BanRoot "service_status.json"
$script:LogRoot = Join-Path $script:BoiiiRoot "scriptdata\pintemod\logs"
$script:HealthRoot = Join-Path $script:BoiiiRoot "scriptdata\pintemod\health"
$script:HeartbeatPath = Join-Path $script:HealthRoot "ban_service.json"
$script:ModerationHistoryRoot = Join-Path $script:BoiiiRoot "scriptdata\pintemod\moderation\history"
$script:HeartbeatSequence = 0

$script:ProtectedOwnerXuids = @(Get-ProtectedOwnerXuids)

foreach ($path in @($script:BanRoot, $script:RequestRoot, $script:ResponseRoot, $script:ActiveRoot, $script:LogRoot, $script:HealthRoot, $script:ModerationHistoryRoot)) {
    Ensure-Directory $path
}

$database = Read-Database
if (Cleanup-ExpiredBans $database) { Save-Database $database }
Rebuild-ActiveMarkers $database
Write-Summary $database
Write-ServiceStatus $database
try { Write-HealthHeartbeat -State 'running' -ActiveBans (@(Get-ActiveEntries $database).Count) } catch { Write-Warning ('Heartbeat write failed: ' + $_.Exception.Message) }

Write-Host "============================================================" -ForegroundColor DarkMagenta
Write-Host " PinteMod v2.1.1 - XUID Ban Service" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor DarkMagenta
Write-Host " Server root : $($script:ServerRoot)" -ForegroundColor Gray
Write-Host " Requests    : $($script:RequestRoot)" -ForegroundColor Gray
Write-Host " Persistence : BOIII_XUID, reason and UTC expiration" -ForegroundColor Gray
Write-Host " Privacy     : no player IP is stored" -ForegroundColor Green
Write-Host " Protected   : $($script:ProtectedOwnerXuids.Count) configured Owner XUID(s)" -ForegroundColor Gray
Write-Host " Press Ctrl+C to stop." -ForegroundColor DarkGray

$lastMaintenance = [DateTime]::MinValue
try {
    while ($true) {
        foreach ($file in @(Get-ChildItem -LiteralPath $script:RequestRoot -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object CreationTimeUtc)) {
            Process-Request -File $file -Database $database
        }

        if (((Get-Date) - $lastMaintenance).TotalSeconds -ge 1) {
            $lastMaintenance = Get-Date
            if (Cleanup-ExpiredBans $database) {
                Save-Database $database
                Write-Summary $database
            }
            Write-ServiceStatus $database
            try { Write-HealthHeartbeat -State 'running' -ActiveBans (@(Get-ActiveEntries $database).Count) } catch { Write-Warning ('Heartbeat write failed: ' + $_.Exception.Message) }
        }

        Start-Sleep -Milliseconds ([Math]::Max(100, $PollIntervalMs))
    }
}
finally {
    try { Write-HealthHeartbeat -State 'stopped' -ActiveBans (@(Get-ActiveEntries $database).Count) } catch { }
    try {
        $status = [PSCustomObject]@{
            schema_version = 1
            version = "2.1.1"
            running = $false
            updated_utc = [DateTime]::UtcNow.ToString("o")
            active_bans = @(Get-ActiveEntries $database).Count
            privacy = "BOIII_XUID only; no IP persisted"
        }
        Write-JsonAtomic -Path $script:StatusPath -Value $status
    }
    catch { }
    if ($mutex) {
        try {
            if ($mutexOwned) { $mutex.ReleaseMutex() | Out-Null }
        }
        catch { }
        $mutex.Dispose()
    }
}
