param(
    [string]$ServerRoot = "",
    [string]$ServerAddress = "",
    [int]$ServerPort = 0,
    [switch]$ResetSecret,
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "PinteMod v2.1.1 - GeoIP Language Bridge"


$mutex = New-Object System.Threading.Mutex($false, "Global\PinteMod_v2_1_GeoIPBridge")
$mutexOwned = $false
try { $mutexOwned = $mutex.WaitOne(0, $false) }
catch [System.Threading.AbandonedMutexException] { $mutexOwned = $true }
if (-not $mutexOwned) {
    $mutex.Dispose()
    throw "PinteMod GeoIP Bridge is already running."
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

        # Standard layout: <server-root>\boiii
        if (Test-Path -LiteralPath (Join-Path $full "boiii")) {
            return $full
        }

        # Bridge installed in <server-root>\boiii\tools.
        # When the inspected folder itself is "boiii", its parent is the root.
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

    # Walk upwards from both the script folder and the current working folder.
    # This supports <root>\tools and <root>\boiii\tools without prompting.
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

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function New-DefaultConfig {
    return [ordered]@{
        server_address = "127.0.0.1"
        server_port = 27017
        poll_interval_ms = 500
        rcon_timeout_ms = 3000
        geoip_endpoint = "https://ipwho.is/{ip}"
        default_language = "en"
        country_language_overrides = [ordered]@{
            FR="fr"; BE="fr"; CH="fr"; LU="fr"; MC="fr"; CA="fr"
            DZ="fr"; MA="fr"; TN="fr"; SN="fr"; CI="fr"; ML="fr"
            NE="fr"; BF="fr"; BJ="fr"; TG="fr"; GA="fr"; CG="fr"
            CD="fr"; CM="fr"; MG="fr"; HT="fr"; DJ="fr"; GN="fr"
            RW="fr"; BI="fr"; TD="fr"; CF="fr"; KM="fr"; MU="fr"
            SC="fr"; VU="fr"
            ES="es"; MX="es"; AR="es"; BO="es"; CL="es"; CO="es"
            CR="es"; CU="es"; DO="es"; EC="es"; SV="es"; GQ="es"
            GT="es"; HN="es"; NI="es"; PA="es"; PY="es"; PE="es"
            PR="es"; UY="es"; VE="es"
        }
    }
}

function Get-Config {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        $default = New-DefaultConfig
        $default | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding UTF8
        Write-Host "Created configuration: $Path" -ForegroundColor Yellow
        return [PSCustomObject]$default
    }

    try {
        return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
    }
    catch {
        throw "Invalid GeoIP Bridge configuration: $($_.Exception.Message)"
    }
}

function Save-RconSecret {
    param([string]$Path)

    Write-Host "The RCON password is encrypted with Windows DPAPI for this account." -ForegroundColor Cyan
    $secure = Read-Host "RCON password" -AsSecureString
    if ($secure.Length -le 0) { throw "Empty RCON password." }
    $encrypted = $secure | ConvertFrom-SecureString
    # Write without BOM or trailing newline. ConvertTo-SecureString expects the
    # DPAPI payload only; Windows PowerShell Set-Content normally appends CRLF.
    [System.IO.File]::WriteAllText(
        $Path,
        $encrypted,
        [System.Text.UTF8Encoding]::new($false)
    )
    Write-Host "Encrypted RCON secret created: $Path" -ForegroundColor Green
}

function Get-RconPassword {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Save-RconSecret -Path $Path
    }

    try {
        $encrypted = (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop).Trim()
        if ([string]::IsNullOrWhiteSpace($encrypted)) {
            throw "Empty encrypted RCON secret."
        }
        $secure = $encrypted | ConvertTo-SecureString -ErrorAction Stop
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    }
    catch {
        throw "Unable to decrypt the RCON secret for the current Windows account. Use -ResetSecret."
    }
}

function Invoke-BoiiiRcon {
    param(
        [string]$Address,
        [int]$Port,
        [string]$Password,
        [string]$Command,
        [int]$TimeoutMs
    )

    $client = [System.Net.Sockets.UdpClient]::new()
    $client.Client.ReceiveTimeout = $TimeoutMs
    $client.Client.SendTimeout = $TimeoutMs

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
        if (-not $response -or $response.Length -le 4) { return "" }

        $offset = 4
        $text = [System.Text.Encoding]::UTF8.GetString($response, $offset, $response.Length - $offset)
        $text = $text -replace '(?i)^print[\s\r\n]+', ''
        return $text
    }
    finally {
        $client.Dispose()
    }
}

function Get-StatusAddressMap {
    param([string]$StatusText)

    $result = @{}
    if ([string]::IsNullOrWhiteSpace($StatusText)) { return $result }

    foreach ($line in ($StatusText -split "`r?`n")) {
        # RCON returns one row per client. Store only the in-memory values
        # needed to validate the request and perform the country lookup.
        if ($line -match '^\s*(?<client>\d+)\s+.*?(?<xuid>[0-9a-fA-F]{15,16})\s+.*?(?<ip>(?:\d{1,3}\.){3}\d{1,3})(?::\d+)?(?:\s|$)') {
            $clientNumber = [int]$matches.client
            $candidate = $matches.ip
            $parsed = $null
            if ([System.Net.IPAddress]::TryParse($candidate, [ref]$parsed)) {
                $result[$clientNumber] = [PSCustomObject]@{
                    xuid = ([string]$matches.xuid).ToLowerInvariant()
                    address = $parsed.ToString()
                }
            }
        }
    }

    return $result
}

function Test-PrivateAddress {
    param([string]$Address)

    $parsed = $null
    if (-not [System.Net.IPAddress]::TryParse($Address, [ref]$parsed)) { return $true }
    $bytes = $parsed.GetAddressBytes()
    if ($bytes.Length -ne 4) { return $false }

    return (
        $bytes[0] -eq 10 -or
        $bytes[0] -eq 127 -or
        ($bytes[0] -eq 169 -and $bytes[1] -eq 254) -or
        ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) -or
        ($bytes[0] -eq 192 -and $bytes[1] -eq 168)
    )
}

function Get-LanguageForCountry {
    param([string]$CountryCode, $Config)

    $code = ([string]$CountryCode).ToUpperInvariant()
    $overrides = $Config.country_language_overrides

    if ($overrides -and $overrides.PSObject.Properties.Name -contains $code) {
        $value = ([string]$overrides.$code).ToLowerInvariant()
        if ($value -in @("fr","en","es")) { return $value }
    }

    $fallback = ([string]$Config.default_language).ToLowerInvariant()
    if ($fallback -notin @("fr","en","es")) { $fallback = "en" }
    return $fallback
}

function Invoke-CountryLookup {
    param([string]$Address, $Config)

    if (Test-PrivateAddress -Address $Address) {
        return [PSCustomObject]@{
            country_code = "LOCAL"
            country_en = "Local network"
            country_fr = "Reseau local"
            country_es = "Red local"
        }
    }

    $endpoint = [string]$Config.geoip_endpoint
    if ([string]::IsNullOrWhiteSpace($endpoint) -or -not $endpoint.Contains("{ip}")) {
        throw "geoip_endpoint must contain {ip}."
    }

    $encoded = [Uri]::EscapeDataString($Address)
    $base = $endpoint.Replace("{ip}", $encoded)
    $names = @{}
    $countryCode = ""

    foreach ($language in @("en","fr","es")) {
        $separator = if ($base.Contains("?")) { "&" } else { "?" }
        $uri = "$base${separator}fields=success,country,country_code&lang=$language"
        $reply = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 8 -ErrorAction Stop
        if (-not $reply.success) { throw "GeoIP provider rejected the lookup." }
        if ([string]::IsNullOrWhiteSpace($countryCode)) { $countryCode = [string]$reply.country_code }
        $names[$language] = [string]$reply.country
    }

    return [PSCustomObject]@{
        country_code = $countryCode.ToUpperInvariant()
        country_en = $names.en
        country_fr = $names.fr
        country_es = $names.es
    }
}

function Write-AtomicJson {
    param([string]$Path, $Value)

    $directory = Split-Path -Parent $Path
    Ensure-Directory $directory
    $temp = "$Path.tmp"
    $json = $Value | ConvertTo-Json -Depth 4 -Compress
    [System.IO.File]::WriteAllText(
        $temp,
        $json,
        [System.Text.UTF8Encoding]::new($false)
    )
    $verified = Get-Content -LiteralPath $temp -Raw | ConvertFrom-Json -ErrorAction Stop
    if (-not $verified) { throw "Temporary response JSON verification failed." }
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Write-BridgeHeartbeat {
    param([string]$State = "configured", [string]$LastErrorCode = "")
    if (-not $script:HeartbeatPath) { return }
    $script:HeartbeatSequence++
    $heartbeat = [ordered]@{
        schema_version = 1
        tool = "geoip_bridge"
        version = "2.1.1"
        state = $State
        sequence = $script:HeartbeatSequence
        updated_utc = [DateTime]::UtcNow.ToString("o")
        last_error_code = $LastErrorCode
        privacy = "No player IP persisted; no secret in heartbeat"
    }
    Write-AtomicJson -Path $script:HeartbeatPath -Value $heartbeat
}

function Read-CountryStatistics {
    if (Test-Path -LiteralPath $script:CountryStatsPath) {
        try {
            $stats = Get-Content -LiteralPath $script:CountryStatsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if (-not $stats.entries) { $stats | Add-Member -NotePropertyName entries -NotePropertyValue @() -Force }
            return $stats
        }
        catch { }
    }
    return [pscustomobject]@{ schema_version = 1; total_connections = 0; entries = @() }
}

function Update-CountryStatistics {
    param([string]$Code, [string]$Name)
    if ([string]::IsNullOrWhiteSpace($Code)) { $Code = 'OTHER' }
    $Code = $Code.ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($Name)) { $Name = $Code }

    $stats = Read-CountryStatistics
    $entries = @($stats.entries)
    $entry = $entries | Where-Object { ([string]$_.code).ToUpperInvariant() -eq $Code } | Select-Object -First 1
    if ($entry) {
        $entry.connections = [int]$entry.connections + 1
        if ($Name) { $entry.name = $Name }
    }
    else {
        $entries += [pscustomobject]@{ code = $Code; name = $Name; connections = 1 }
    }
    $stats.schema_version = 1
    $stats.total_connections = [int]$stats.total_connections + 1
    $stats.entries = @($entries | Sort-Object @{Expression='connections';Descending=$true}, code)
    Write-AtomicJson -Path $script:CountryStatsPath -Value $stats

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($item in $stats.entries) {
        $display = if ($item.name) { [string]$item.name } else { [string]$item.code }
        $lines.Add(('{0,-20} {1,7}' -f $display, [int]$item.connections)) | Out-Null
    }
    [System.IO.File]::WriteAllLines($script:CountrySummaryPath, [string[]]$lines, [System.Text.UTF8Encoding]::new($false))
}

function Read-RequestIdentity {
    param([System.IO.FileInfo]$RequestFile)

    try {
        $request = Get-Content -LiteralPath $RequestFile.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $xuid = ([string]$request.xuid).ToLowerInvariant()
        $clientNumber = [int]$request.client
        if ($xuid -notmatch '^[0-9a-f]{15,16}$' -or $clientNumber -lt 0) { return $null }
        return [PSCustomObject]@{ xuid=$xuid; client=$clientNumber }
    }
    catch { return $null }
}

function Test-StatusCacheCoversRequests {
    param($AddressMap, [System.IO.FileInfo[]]$Requests)

    if (-not $AddressMap -or $AddressMap.Count -eq 0) { return $false }

    foreach ($requestFile in $Requests) {
        $identity = Read-RequestIdentity -RequestFile $requestFile
        if (-not $identity) { continue }
        if (-not $AddressMap.ContainsKey([int]$identity.client)) { return $false }
        $entry = $AddressMap[[int]$identity.client]
        if (([string]$entry.xuid).ToLowerInvariant() -ne ([string]$identity.xuid).ToLowerInvariant()) { return $false }
    }

    return $true
}

function Get-StatusSnapshot {
    param(
        [System.IO.FileInfo[]]$Requests,
        [string]$Address,
        [int]$Port,
        [string]$Password,
        [int]$TimeoutMs
    )

    $cacheAge = ((Get-Date) - $script:StatusCacheTime).TotalSeconds
    if ($cacheAge -le 10 -and (Test-StatusCacheCoversRequests -AddressMap $script:StatusCache -Requests $Requests)) {
        return $script:StatusCache
    }

    # A joining client can need a moment before appearing in status. Avoid
    # flooding the native BOIII console while the same request is pending.
    if ($cacheAge -lt 3) {
        return $script:StatusCache
    }

    $status = Invoke-BoiiiRcon -Address $Address -Port $Port -Password $Password -Command "status" -TimeoutMs $TimeoutMs
    $script:StatusCache = Get-StatusAddressMap -StatusText $status
    $script:StatusCacheTime = Get-Date
    return $script:StatusCache
}

function Process-Request {
    param(
        [System.IO.FileInfo]$RequestFile,
        $Config,
        $AddressMap,
        [string]$Address,
        [int]$Port
    )

    try {
        $request = Get-Content -LiteralPath $RequestFile.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $xuid = ([string]$request.xuid).ToLowerInvariant()
        $clientNumber = [int]$request.client

        if ($xuid -notmatch '^[0-9a-f]{15,16}$' -or $clientNumber -lt 0) {
            throw "Invalid XUID/client request."
        }

        if (-not $AddressMap.ContainsKey($clientNumber)) {
            throw "Client slot #$clientNumber was not found in the current RCON status snapshot."
        }

        $clientEntry = $AddressMap[$clientNumber]
        if (([string]$clientEntry.xuid).ToLowerInvariant() -ne $xuid) {
            throw "Client slot #$clientNumber XUID changed before GeoIP processing; the request will be retried."
        }

        # The address exists only in this function's memory. It is never logged or written.
        $country = Invoke-CountryLookup -Address ([string]$clientEntry.address) -Config $Config
        $language = Get-LanguageForCountry -CountryCode $country.country_code -Config $Config

        $response = [ordered]@{
            xuid = $xuid
            language = $language
            country_code = $country.country_code
            country_en = $country.country_en
            country_fr = $country.country_fr
            country_es = $country.country_es
        }

        $responsePath = Join-Path $script:ResponseRoot "$xuid.json"
        Write-AtomicJson -Path $responsePath -Value $response
        Update-CountryStatistics -Code ([string]$country.country_code) -Name ([string]$country.country_en)
        $script:BridgeState = 'connected'
        $script:BridgeLastError = ''
        Remove-Item -LiteralPath $RequestFile.FullName -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath ($RequestFile.FullName + ".bak") -Force -ErrorAction SilentlyContinue

        Write-Host "[GEOIP] client=#$clientNumber xuid=$xuid country=$($country.country_code) language=$language" -ForegroundColor Green
        return $true
    }
    catch {
        $key = $RequestFile.FullName
        $rawMessage = $_.Exception.Message
        $displayMessage = $rawMessage

        if ($_.Exception -is [System.Net.Sockets.SocketException] -or
            $rawMessage -match '(?i)Receive|timed? out|délai|n.a pas répondu') {
            $displayMessage = "RCON timeout: no response from ${Address}:$Port. Check rcon_password and net_port; the request will be retried."
        }

        $now = Get-Date
        $last = $script:LastErrors[$key]
        if (-not $last -or $last.Message -ne $displayMessage -or ($now - $last.Time).TotalSeconds -ge 30) {
            Write-Host "[WARN] $displayMessage No player IP was logged or written." -ForegroundColor Yellow
            $script:LastErrors[$key] = [PSCustomObject]@{ Message=$displayMessage; Time=$now }
        }
        return $false
    }
}

function Invoke-SelfTest {
    $sample = @"
map: zm_tomb
num score ping xuid name lastmsg address qport rate
  0     0   42 9cf34426f668fb8b BiereFraiche 0 203.0.113.10:27005 1234 25000
  2     0   55 1111111111111111 gumball 0 198.51.100.25:27005 2345 25000
"@
    $map = Get-StatusAddressMap -StatusText $sample
    if ($map.Count -ne 2 -or
        $map[0].address -ne "203.0.113.10" -or
        $map[0].xuid -ne "9cf34426f668fb8b" -or
        $map[2].address -ne "198.51.100.25" -or
        $map[2].xuid -ne "1111111111111111") {
        throw "RCON status parser self-test failed."
    }
    Write-Host "GeoIP Bridge self-test: PASS" -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-SelfTest
    exit 0
}

$script:ServerRoot = Resolve-ServerRoot -RequestedRoot $ServerRoot
$script:LocalizationRoot = Join-Path $script:ServerRoot "boiii\scriptdata\pintemod\localization"
$script:RequestRoot = Join-Path $script:LocalizationRoot "requests"
$script:ResponseRoot = Join-Path $script:LocalizationRoot "responses"
$script:StatsRoot = Join-Path $script:LocalizationRoot "stats"
$script:CountryStatsPath = Join-Path $script:StatsRoot "countries.json"
$script:CountrySummaryPath = Join-Path $script:StatsRoot "countries_summary.txt"
$script:HealthRoot = Join-Path $script:ServerRoot "boiii\scriptdata\pintemod\health"
$script:HeartbeatPath = Join-Path $script:HealthRoot "geoip_bridge.json"
$script:HeartbeatSequence = 0
$script:BridgeState = 'running'
$script:BridgeLastError = ''
Ensure-Directory $script:RequestRoot
Ensure-Directory $script:ResponseRoot
Ensure-Directory $script:StatsRoot
Ensure-Directory $script:HealthRoot

$configPath = Join-Path $PSScriptRoot "PinteMod_GeoIP_Bridge.local.json"
$secretPath = Join-Path $PSScriptRoot "PinteMod_GeoIP_Bridge.secret.txt"

if ($ResetSecret) {
    Remove-Item -LiteralPath $secretPath -Force -ErrorAction SilentlyContinue
    Write-Host "Encrypted RCON secret removed." -ForegroundColor Yellow
}

$config = Get-Config -Path $configPath
if (-not [string]::IsNullOrWhiteSpace($ServerAddress)) { $config.server_address = $ServerAddress }
if ($ServerPort -gt 0) { $config.server_port = $ServerPort }
$password = Get-RconPassword -Path $secretPath
$script:LastErrors = @{}
$script:StatusCache = @{}
$script:StatusCacheTime = [DateTime]::MinValue

Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host " PinteMod v2.1.1 - GeoIP Language Bridge" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host " Server       : $($config.server_address):$($config.server_port)" -ForegroundColor Gray
Write-Host " Requests     : $script:RequestRoot" -ForegroundColor Gray
Write-Host " Languages    : FR / EN / ES" -ForegroundColor Gray
Write-Host " Privacy      : bridge never logs or stores player IPs" -ForegroundColor Green
Write-Host " BOIII note   : one raw status block may appear for each fresh join batch" -ForegroundColor Yellow
Write-Host " Persistent   : BOIII_XUID + language only" -ForegroundColor Green
Write-Host " Press Ctrl+C to stop." -ForegroundColor DarkGray
Write-Host ""
try { Write-BridgeHeartbeat -State $script:BridgeState } catch { Write-Warning ('Heartbeat write failed: ' + $_.Exception.Message) }

try {
while ($true) {
    $requests = @(Get-ChildItem -LiteralPath $script:RequestRoot -Filter "*.json" -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)

    if ($requests.Count -gt 0) {
        try {
            # A single RCON snapshot serves the complete pending batch. A valid
            # XUID-aware snapshot is cached briefly so GeoIP/API retries do not
            # print the full BOIII status block again.
            $addressMap = Get-StatusSnapshot `
                -Requests $requests `
                -Address ([string]$config.server_address) `
                -Port ([int]$config.server_port) `
                -Password $password `
                -TimeoutMs ([int]$config.rcon_timeout_ms)

            foreach ($requestFile in $requests) {
                [void](Process-Request `
                    -RequestFile $requestFile `
                    -Config $config `
                    -AddressMap $addressMap `
                    -Address ([string]$config.server_address) `
                    -Port ([int]$config.server_port))
            }
        }
        catch {
            $rawMessage = $_.Exception.Message
            $script:BridgeState = 'error'
            $script:BridgeLastError = 'RCON_OR_LOOKUP_ERROR'
            $displayMessage = $rawMessage
            if ($_.Exception -is [System.Net.Sockets.SocketException] -or
                $rawMessage -match '(?i)Receive|timed? out|délai|n.a pas répondu') {
                $displayMessage = "RCON timeout: no response from $($config.server_address):$($config.server_port). Check rcon_password and net_port; requests will be retried."
            }

            $now = Get-Date
            $last = $script:LastErrors['__status_batch__']
            if (-not $last -or $last.Message -ne $displayMessage -or ($now - $last.Time).TotalSeconds -ge 30) {
                Write-Host "[WARN] $displayMessage No player IP was logged or written." -ForegroundColor Yellow
                $script:LastErrors['__status_batch__'] = [PSCustomObject]@{ Message=$displayMessage; Time=$now }
            }
        }

        # Respect BOIII's default RCON rate limit before another fresh snapshot.
        Start-Sleep -Milliseconds 550
    }

    try { Write-BridgeHeartbeat -State $script:BridgeState -LastErrorCode $script:BridgeLastError } catch { Write-Warning ('Heartbeat write failed: ' + $_.Exception.Message) }
    Start-Sleep -Milliseconds ([Math]::Max(250, [int]$config.poll_interval_ms))
}
}
finally {
    try { Write-BridgeHeartbeat -State 'stopped' -LastErrorCode $script:BridgeLastError } catch { }
    if ($mutex) {
        try { if ($mutexOwned) { $mutex.ReleaseMutex() | Out-Null } } catch { }
        $mutex.Dispose()
    }
}
