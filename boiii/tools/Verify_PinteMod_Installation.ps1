param(
    [string]$ServerRoot = "",
    [switch]$Deep,
    [switch]$RemoteToolsMachine,
    [switch]$PublicPackageAudit,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'PinteMod v2.1.1 - Installation Verifier'

$script:PassCount = 0
$script:WarningCount = 0
$script:ErrorCount = 0
$script:Results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [ValidateSet('PASS','WARNING','ERROR')][string]$Status,
        [string]$Check,
        [string]$Details,
        [string]$Recommendation = ''
    )
    switch ($Status) {
        'PASS' { $script:PassCount++; $color='Green' }
        'WARNING' { $script:WarningCount++; $color='Yellow' }
        'ERROR' { $script:ErrorCount++; $color='Red' }
    }
    $script:Results.Add([pscustomobject]@{
        status=$Status; check=$Check; details=$Details; recommendation=$Recommendation
    }) | Out-Null
    Write-Host ('[{0,-7}] {1}' -f $Status,$Check) -ForegroundColor $color
    if ($Details) { Write-Host ('          ' + $Details) -ForegroundColor Gray }
    if ($Recommendation) { Write-Host ('          Recommendation: ' + $Recommendation) -ForegroundColor DarkGray }
}

function Resolve-PinteModRoot {
    param([string]$Requested)
    $seeds = @($Requested,$PSScriptRoot,(Get-Location).Path) | Where-Object { $_ } | Select-Object -Unique
    foreach ($seed in $seeds) {
        try { $candidate=[IO.Path]::GetFullPath($seed.Trim('"')) } catch { continue }
        for($i=0;$i -lt 8 -and $candidate;$i++) {
            if((Test-Path -LiteralPath (Join-Path $candidate 'boiii\custom_scripts')) -and
               (Test-Path -LiteralPath (Join-Path $candidate 'boiii\tools'))) { return $candidate }
            if((Split-Path -Leaf $candidate) -ieq 'boiii' -and
               (Test-Path -LiteralPath (Join-Path $candidate 'custom_scripts'))) { return (Split-Path -Parent $candidate) }
            $parent=Split-Path -Parent $candidate
            if(-not $parent -or $parent -eq $candidate){break}
            $candidate=$parent
        }
    }
    throw 'Unable to locate the UnrankedServer folder containing boiii\custom_scripts and boiii\tools.'
}

function Test-WritableFolder {
    param([string]$Path)
    try {
        if(-not (Test-Path -LiteralPath $Path)){ New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        $probe=Join-Path $Path ('.pintemod_write_test_' + [guid]::NewGuid().ToString('N') + '.tmp')
        [IO.File]::WriteAllText($probe,'test',[Text.UTF8Encoding]::new($false))
        Remove-Item -LiteralPath $probe -Force
        return $true
    } catch { return $false }
}

function Get-DpapiSecret {
    param([string]$Path)
    $encrypted=(Get-Content -LiteralPath $Path -Raw -ErrorAction Stop).Trim()
    if([string]::IsNullOrWhiteSpace($encrypted)){throw 'Encrypted secret is empty.'}
    $secure=$encrypted | ConvertTo-SecureString -ErrorAction Stop
    $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

function Get-ServerRconPassword {
    param([string]$Path)
    if(-not (Test-Path -LiteralPath $Path)){return $null}
    $text=Get-Content -LiteralPath $Path -Raw
    $m=[regex]::Match($text,'(?im)^\s*(?:set\s+)?rcon_password\s+"(?<password>[^"\r\n]+)"\s*$')
    if($m.Success){return $m.Groups['password'].Value}
    return $null
}

function Get-NetPortFromText {
    param([string]$Text)
    if([string]::IsNullOrWhiteSpace($Text)){return 0}
    $patterns=@(
        '(?im)^\s*(?:set\s+)?net_port\s+"?(?<port>\d+)"?(?:\s|//|$)',
        '(?im)(?:^|\s)\+set\s+net_port\s+"?(?<port>\d+)"?(?:\s|$)',
        '(?im)\bnet_port\b\s*[=:]\s*"?(?<port>\d+)"?'
    )
    foreach($pattern in $patterns){
        $m=[regex]::Match($Text,$pattern)
        if($m.Success){return [int]$m.Groups['port'].Value}
    }
    return 0
}

function Expand-SimpleBatchVariables {
    param([string]$Text)
    if([string]::IsNullOrWhiteSpace($Text)){return $Text}
    $variables=@{}
    foreach($line in ($Text -split "`r?`n")){
        $m=[regex]::Match($line,'(?i)^\s*set\s+"?(?<name>[A-Za-z_][A-Za-z0-9_]*)=(?<value>[^"\r\n]*)"?\s*$')
        if($m.Success){$variables[$m.Groups['name'].Value]=$m.Groups['value'].Value.Trim()}
    }
    $expanded=$Text
    foreach($name in $variables.Keys){
        $expanded=[regex]::Replace($expanded,('%'+[regex]::Escape($name)+'%'),[string]$variables[$name],[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    return $expanded
}

function Get-NetPort {
    param([string]$Path)
    if([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)){return 0}
    $text=Get-Content -LiteralPath $Path -Raw
    $port=Get-NetPortFromText $text
    if($port -gt 0){return $port}
    if([IO.Path]::GetExtension($Path) -ieq '.bat'){
        return Get-NetPortFromText (Expand-SimpleBatchVariables $text)
    }
    return 0
}

function Get-RunningDedicatedNetPort {
    try{
        foreach($process in @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {$_.CommandLine -and $_.CommandLine -match '(?i)(?:^|\s)-dedicated(?:\s|$)'})){
            $port=Get-NetPortFromText ([string]$process.CommandLine)
            if($port -gt 0){return $port}
        }
    }catch{}
    return 0
}

function Get-RecentBoundNetPort {
    param([string]$SearchRoot)
    try{
        $logs=@(Get-ChildItem -LiteralPath $SearchRoot -Filter '*.log' -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object {$_.Length -le 10485760} |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 20)
        foreach($log in $logs){
            $tail=(Get-Content -LiteralPath $log.FullName -Tail 1200 -ErrorAction SilentlyContinue) -join "`n"
            $m=[regex]::Match($tail,'(?im)Socket bound on port\s+(?<port>\d+)')
            if($m.Success){return [int]$m.Groups['port'].Value}
            $port=Get-NetPortFromText $tail
            if($port -gt 0){return $port}
        }
    }catch{}
    return 0
}

function Get-RunningScriptProcesses {
    param([string]$ScriptPath)
    try {
        $escaped=[regex]::Escape([IO.Path]::GetFullPath($ScriptPath))
        return @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {$_.CommandLine -and $_.CommandLine -match $escaped})
    } catch { return @() }
}

function Test-PowerShellSyntax {
    param([string]$Path)
    $tokens=$null; $errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    return @($errors)
}

function Remove-GscCommentsAndStrings {
    param([string]$Text)
    $sb=New-Object Text.StringBuilder
    $inString=$false; $inLine=$false; $inBlock=$false; $escape=$false
    for($i=0;$i -lt $Text.Length;$i++){
        $c=$Text[$i]; $n=if($i+1 -lt $Text.Length){$Text[$i+1]}else{[char]0}
        if($inLine){ if($c -eq "`n"){$inLine=$false;[void]$sb.Append("`n")}else{[void]$sb.Append(' ')}; continue }
        if($inBlock){ if($c -eq '*' -and $n -eq '/'){$inBlock=$false;[void]$sb.Append('  ');$i++}else{[void]$sb.Append($(if($c -eq "`n"){"`n"}else{' '}))}; continue }
        if($inString){
            if($escape){$escape=$false;[void]$sb.Append(' ');continue}
            if($c -eq '\'){$escape=$true;[void]$sb.Append(' ');continue}
            if($c -eq '"'){$inString=$false}
            [void]$sb.Append($(if($c -eq "`n"){"`n"}else{' '}));continue
        }
        if($c -eq '/' -and $n -eq '/'){$inLine=$true;[void]$sb.Append('  ');$i++;continue}
        if($c -eq '/' -and $n -eq '*'){$inBlock=$true;[void]$sb.Append('  ');$i++;continue}
        if($c -eq '"'){$inString=$true;[void]$sb.Append(' ');continue}
        [void]$sb.Append($c)
    }
    return $sb.ToString()
}

function Test-GscBalance {
    param([string]$Path)
    $clean=Remove-GscCommentsAndStrings (Get-Content -LiteralPath $Path -Raw)
    $pairs=@(@('{','}'),@('(',')'),@('[',']'))
    $issues=New-Object System.Collections.Generic.List[string]
    foreach($pair in $pairs){
        $open=([regex]::Matches($clean,[regex]::Escape($pair[0]))).Count
        $close=([regex]::Matches($clean,[regex]::Escape($pair[1]))).Count
        if($open -ne $close){$issues.Add("$($pair[0])/$($pair[1]) $open/$close")|Out-Null}
    }
    return @($issues)
}

function Find-ServerLauncherCandidates {
    param([string]$Root)
    $excluded=@('Launch_PinteMod_Server.bat','Launch_PinteMod_Server_Only.bat','Launch_PinteMod_Remote_Tools.bat','Configure_PinteMod_RCON.bat','Verify_PinteMod_Installation.bat','Test_PinteMod_v2.1.1.bat')
    return @(Get-ChildItem -LiteralPath $Root -File -ErrorAction SilentlyContinue | Where-Object {
        $_.Extension -in @('.bat','.cmd') -and $_.Name -notin $excluded
    } | Where-Object {
        try { $t=Get-Content -LiteralPath $_.FullName -Raw; $_.Name -match '(?i)(server|boiii|start|launch)' -or $t -match '(?i)(boiii(?:\.exe)?|server_zm|dedicated)' } catch {$false}
    })
}

$root=Resolve-PinteModRoot -Requested $ServerRoot
$boiii=Join-Path $root 'boiii'
$custom=Join-Path $boiii 'custom_scripts'
$tools=Join-Path $boiii 'tools'
$scriptdata=Join-Path $boiii 'scriptdata\pintemod'
$zone=Join-Path $root 'zone'

Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host ' PinteMod v2.1.1 - Installation Verifier' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host (' Root: ' + $root) -ForegroundColor Gray
Write-Host (' Mode: ' + $(if($PublicPackageAudit){'PUBLIC PACKAGE AUDIT'}elseif($RemoteToolsMachine){'REMOTE TOOLS MACHINE'}else{'LOCAL SERVER'})) -ForegroundColor Gray
Write-Host ''

# Layout and paths
if((Split-Path -Leaf $root) -ieq 'boiii') { Add-Result ERROR 'Server root' 'The selected root is boiii instead of UnrankedServer.' 'Run launchers from the folder that contains boiii.' }
else { Add-Result PASS 'Server root' 'UnrankedServer layout detected.' }

foreach($required in @(
    @{Name='custom_scripts';Path=$custom},@{Name='tools';Path=$tools}
)){
    if(Test-Path -LiteralPath $required.Path -PathType Container){Add-Result PASS $required.Name $required.Path}
    else{Add-Result ERROR $required.Name ('Missing: '+$required.Path) 'Extract the complete package directly into UnrankedServer.'}
}

$rootLaunchers=@('Launch_PinteMod_Server.bat','Launch_PinteMod_Server_Only.bat','Launch_PinteMod_Remote_Tools.bat','Configure_PinteMod_RCON.bat','Verify_PinteMod_Installation.bat','Test_PinteMod_v2.1.1.bat')
foreach($name in $rootLaunchers){
    $path=Join-Path $root $name
    if(Test-Path -LiteralPath $path -PathType Leaf){Add-Result PASS ('Launcher '+$name) 'Correct root location.'}
    else{Add-Result ERROR ('Launcher '+$name) 'Missing from UnrankedServer root.' 'Restore it from the public package.'}
}
$misplaced=New-Object System.Collections.Generic.List[string]
foreach($name in $rootLaunchers){
    foreach($file in @(Get-ChildItem -LiteralPath $boiii -Filter $name -File -Recurse -ErrorAction SilentlyContinue)){
        $misplaced.Add($file.FullName)|Out-Null
    }
}
if($misplaced.Count -gt 0){Add-Result WARNING 'Misplaced principal launchers' (($misplaced -join '; ')) 'Keep principal launchers only at UnrankedServer root. Helper launchers inside boiii\tools are intentional.'}
else{Add-Result PASS 'Principal launcher locations' 'Principal launchers are present only at UnrankedServer root; helper launchers in boiii\tools are valid.'}

# Writable runtime locations
if(Test-WritableFolder $custom){Add-Result PASS 'custom_scripts access' 'Folder is accessible and writable.'}else{Add-Result ERROR 'custom_scripts access' 'Folder is not writable.' 'Check Windows permissions and server path.'}
if($PublicPackageAudit){
    if(Test-Path -LiteralPath (Join-Path $boiii 'scriptdata')){Add-Result ERROR 'Public scriptdata exclusion' 'boiii\scriptdata exists in the audited package.' 'Remove all runtime data before publication.'}
    else{Add-Result PASS 'Public scriptdata exclusion' 'No scriptdata embedded.'}
}else{
    if(Test-WritableFolder $scriptdata){Add-Result PASS 'scriptdata access' 'boiii\scriptdata\pintemod is accessible.'}else{Add-Result ERROR 'scriptdata access' 'Runtime data folder cannot be created or written.' 'Check service account and NTFS permissions.'}
}

# GSC inventory / duplicates / versions / imports
$allCustomGsc=@(Get-ChildItem -LiteralPath $custom -Filter '*.gsc' -File -ErrorAction SilentlyContinue)
$gsc=@($allCustomGsc | Where-Object {$_.Name -like 'ezz_admin*.gsc'})
$externalGsc=@($allCustomGsc | Where-Object {$_.Name -notlike 'ezz_admin*.gsc'})
if($gsc.Count -eq 28){Add-Result PASS 'PinteMod GSC module count' ("28 PinteMod modules found; $($externalGsc.Count) external compatibility/custom GSC file(s) ignored by source checks.")}
elseif($gsc.Count -lt 28){Add-Result ERROR 'PinteMod GSC module count' ("Only $($gsc.Count) PinteMod modules found; v2.1.1 expects 28.") 'Re-extract the complete public package.'}
else{Add-Result ERROR 'PinteMod GSC module count' ("$($gsc.Count) PinteMod modules found; v2.1.1 expects exactly 28.") 'Remove stale or duplicated ezz_admin modules.'}

$allServerGsc=@(Get-ChildItem -LiteralPath $root -Filter '*.gsc' -File -Recurse -ErrorAction SilentlyContinue)
$duplicates=@($allServerGsc | Group-Object Name | Where-Object {$_.Count -gt 1})
if($duplicates.Count){Add-Result ERROR 'Duplicate GSC modules' (($duplicates | ForEach-Object {"$($_.Name) x$($_.Count)"}) -join '; ') 'Delete old duplicate copies and keep modules only in boiii\custom_scripts.'}
else{Add-Result PASS 'Duplicate GSC modules' 'No duplicate filename found.'}

$oldLocations=@($allServerGsc | Where-Object {$_.DirectoryName -ne $custom -and $_.Name -like 'ezz_admin*.gsc'})
if($oldLocations.Count){Add-Result ERROR 'Old PinteMod scripts outside custom_scripts' (($oldLocations.FullName -join '; ')) 'Remove legacy copies.'}
else{Add-Result PASS 'Old PinteMod scripts outside custom_scripts' 'None found.'}

$commands=New-Object System.Collections.Generic.List[string]
$missingImports=New-Object System.Collections.Generic.List[string]
$balanceIssues=New-Object System.Collections.Generic.List[string]
$bomIssues=New-Object System.Collections.Generic.List[string]
foreach($file in $gsc){
    $text=Get-Content -LiteralPath $file.FullName -Raw
    foreach($m in [regex]::Matches($text,'(?i)addcommand\s*\(\s*"([^"]+)"')){$commands.Add($m.Groups[1].Value.ToLowerInvariant())|Out-Null}
    foreach($m in [regex]::Matches($text,'(?im)^\s*#using\s+custom_scripts\\([^;]+);')){
        $dep=Join-Path $custom ($m.Groups[1].Value+'.gsc')
        if(-not (Test-Path -LiteralPath $dep)){$missingImports.Add("$($file.Name) -> $($m.Groups[1].Value).gsc")|Out-Null}
    }
    foreach($issue in @(Test-GscBalance $file.FullName)){$balanceIssues.Add("$($file.Name): $issue")|Out-Null}
    $bytes=[IO.File]::ReadAllBytes($file.FullName)
    if($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF){
        $bomIssues.Add($file.Name)|Out-Null
    }
}
$duplicateCommands=@($commands | Group-Object | Where-Object {$_.Count -gt 1})
if($duplicateCommands.Count){Add-Result ERROR 'Duplicate console commands' (($duplicateCommands | ForEach-Object {"$($_.Name) x$($_.Count)"}) -join '; ') 'Remove duplicate addcommand registrations.'}
else{Add-Result PASS 'Console command registry' ("$($commands.Count) unique command registrations.")}
if($missingImports.Count){Add-Result ERROR 'GSC imports' ($missingImports -join '; ') 'Restore missing module files.'}else{Add-Result PASS 'GSC imports' 'All local imports resolve.'}
if($balanceIssues.Count){Add-Result ERROR 'GSC delimiter balance' ($balanceIssues -join '; ') 'Correct the listed GSC syntax.'}else{Add-Result PASS 'GSC delimiter balance' 'Braces, parentheses and brackets are balanced.'}
if($bomIssues.Count){Add-Result ERROR 'GSC text encoding' (($bomIssues -join '; ') + ' contain an UTF-8 BOM.') 'Save every PinteMod GSC as UTF-8 without BOM; BOIII may fail to create the script parse tree otherwise.'}
else{Add-Result PASS 'GSC text encoding' 'All PinteMod GSC files are UTF-8/ASCII compatible without BOM.'}

$requiredNew=@('ezz_admin_health.gsc','ezz_admin_langstats.gsc','ezz_admin_moderation.gsc','ezz_admin_map_audit.gsc','ezz_admin_validation.gsc')
foreach($name in $requiredNew){if(Test-Path -LiteralPath (Join-Path $custom $name)){Add-Result PASS ('v2.1.1 module '+$name) 'Present.'}else{Add-Result ERROR ('v2.1.1 module '+$name) 'Missing.' 'Re-extract the v2.1.1 package.'}}

# PowerShell syntax and dependencies
if($PSVersionTable.PSVersion.Major -ge 5){Add-Result PASS 'PowerShell version' ([string]$PSVersionTable.PSVersion)}else{Add-Result ERROR 'PowerShell version' ([string]$PSVersionTable.PSVersion) 'Install Windows PowerShell 5.1 or newer.'}
foreach($cmd in @('ConvertFrom-Json','ConvertTo-Json','ConvertTo-SecureString','Start-Process','Get-CimInstance')){
    if(Get-Command $cmd -ErrorAction SilentlyContinue){Add-Result PASS ('PowerShell dependency '+$cmd) 'Available.'}else{Add-Result ERROR ('PowerShell dependency '+$cmd) 'Missing.' 'Repair or update Windows PowerShell.'}
}
$psFiles=@(Get-ChildItem -LiteralPath $tools -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$parseFailures=New-Object System.Collections.Generic.List[string]
foreach($file in $psFiles){foreach($err in @(Test-PowerShellSyntax $file.FullName)){$parseFailures.Add("$($file.Name): line $($err.Extent.StartLineNumber): $($err.Message)")|Out-Null}}
if($parseFailures.Count){Add-Result ERROR 'PowerShell AST syntax' ($parseFailures -join '; ') 'Correct parser errors before launching.'}
else{Add-Result PASS 'PowerShell AST syntax' ("$($psFiles.Count) scripts parsed without error.")}

# BAT sanity
$batFiles=@(Get-ChildItem -LiteralPath $root -Filter '*.bat' -File -ErrorAction SilentlyContinue)+@(Get-ChildItem -LiteralPath $tools -Filter '*.bat' -File -ErrorAction SilentlyContinue)
$batIssues=New-Object System.Collections.Generic.List[string]
foreach($file in $batFiles){
    $text=Get-Content -LiteralPath $file.FullName -Raw
    if($text -notmatch '(?im)^\s*@echo off'){$batIssues.Add("$($file.Name): missing @echo off")|Out-Null}
    if($text -match '(?i)PinteMod_v2\.1\.0'){$batIssues.Add("$($file.Name): old version reference")|Out-Null}
    if($text -match '(?i)hotfix\.gsc'){$batIssues.Add("$($file.Name): must not distribute hotfix.gsc")|Out-Null}
}
if($batIssues.Count){Add-Result ERROR 'BAT sanity' ($batIssues -join '; ') 'Correct the listed launcher.'}else{Add-Result PASS 'BAT sanity' ("$($batFiles.Count) BAT files passed static checks.")}

# BOIII compatibility file: required locally, forbidden in public package.
$hotfix=Join-Path $custom 'hotfix.gsc'
if($PublicPackageAudit){
    if(Test-Path -LiteralPath $hotfix){Add-Result ERROR 'hotfix.gsc public exclusion' 'hotfix.gsc is embedded.' 'Remove it; PinteMod never distributes this BOIII compatibility file.'}
    else{Add-Result PASS 'hotfix.gsc public exclusion' 'Not distributed.'}
}else{
    if(Test-Path -LiteralPath $hotfix){Add-Result PASS 'BOIII hotfix.gsc' 'Present locally; it remains outside PinteMod ownership.'}
    else{Add-Result WARNING 'BOIII hotfix.gsc' 'Not found in boiii\custom_scripts.' 'Install the BOIII compatibility file from your BOIII/server distribution if your setup requires it; do not obtain it from PinteMod.'}
}

# Server launcher resolution
$launcherConfig=Join-Path $tools 'PinteMod_Server_Launcher.local.json'
$launcherCandidate=$null
if($PublicPackageAudit){
    Add-Result PASS 'BOIII launcher discovery' 'Skipped for the clean public package; the real server launcher is local to UnrankedServer.'
}else{
    if(Test-Path -LiteralPath $launcherConfig){
        try{
            $lc=Get-Content -LiteralPath $launcherConfig -Raw|ConvertFrom-Json
            if($lc.server_launcher){$launcherCandidate=[string]$lc.server_launcher;if(-not [IO.Path]::IsPathRooted($launcherCandidate)){$launcherCandidate=Join-Path $root $launcherCandidate}}
        }catch{Add-Result ERROR 'Server launcher configuration' $_.Exception.Message 'Delete the invalid local JSON and rerun the launcher.'}
    }
    if($launcherCandidate){
        if(Test-Path -LiteralPath $launcherCandidate -PathType Leaf){Add-Result PASS 'Configured BOIII launcher' $launcherCandidate}else{Add-Result ERROR 'Configured BOIII launcher' ('Not found: '+$launcherCandidate) 'Correct PinteMod_Server_Launcher.local.json.'}
    }else{
        $candidates=@(Find-ServerLauncherCandidates $root)
        if($candidates.Count -eq 1){Add-Result PASS 'BOIII launcher discovery' $candidates[0].FullName}
        elseif($candidates.Count -gt 1){Add-Result WARNING 'BOIII launcher discovery' ("$($candidates.Count) candidates: "+($candidates.Name -join ', ')) 'Launch once and choose/configure the intended BOIII server BAT.'}
        else{Add-Result ERROR 'BOIII launcher discovery' 'No existing BOIII server BAT/CMD was found.' 'Place or configure the real BOIII server launcher at UnrankedServer root.'}
    }
}

# RCON and local/remote mode
$serverCfg=Join-Path $zone 'server_zm.cfg'
$secretCfg=Join-Path $zone 'pintemod_server_secrets.cfg'
$geoConfig=Join-Path $tools 'PinteMod_GeoIP_Bridge.local.json'
$geoSecret=Join-Path $tools 'PinteMod_GeoIP_Bridge.secret.txt'

if($PublicPackageAudit){
    foreach($private in @($secretCfg,$geoConfig,$geoSecret,$launcherConfig)){
        if(Test-Path -LiteralPath $private){Add-Result ERROR 'Private file exclusion' ('Embedded: '+$private) 'Remove all local configuration and secret files.'}
    }
}else{
    if(Test-Path -LiteralPath $serverCfg){Add-Result PASS 'server_zm.cfg' 'Found.'}else{Add-Result ERROR 'server_zm.cfg' ('Missing: '+$serverCfg) 'Restore your BOIII server configuration.'}
    if(Test-Path -LiteralPath $secretCfg){Add-Result PASS 'RCON server secret file' 'Found locally.'}else{Add-Result ERROR 'RCON server secret file' 'pintemod_server_secrets.cfg is missing.' 'Run Configure_PinteMod_RCON.bat.'}
    if(Test-Path -LiteralPath $geoConfig){Add-Result PASS 'GeoIP local configuration' 'Found locally.'}else{Add-Result ERROR 'GeoIP local configuration' 'PinteMod_GeoIP_Bridge.local.json is missing.' 'Run Configure_PinteMod_RCON.bat.'}
    if(Test-Path -LiteralPath $geoSecret){Add-Result PASS 'GeoIP DPAPI secret' 'Found locally.'}else{Add-Result ERROR 'GeoIP DPAPI secret' 'Encrypted secret is missing.' 'Run Configure_PinteMod_RCON.bat under the Windows account that runs the tools.'}

    $cfgPassword=Get-ServerRconPassword $secretCfg
    $dpapiPassword=$null
    if($geoSecret -and (Test-Path -LiteralPath $geoSecret)){
        try{$dpapiPassword=Get-DpapiSecret $geoSecret;Add-Result PASS 'DPAPI decryptability' 'Secret is readable by the current Windows account and machine.'}
        catch{Add-Result ERROR 'DPAPI decryptability' $_.Exception.Message 'Delete/recreate the secret with Configure_PinteMod_RCON.bat on this account and machine.'}
    }
    if($cfgPassword -and $dpapiPassword){
        if($cfgPassword -ceq $dpapiPassword){Add-Result PASS 'RCON secret coherence' 'BOIII and bridge secrets match.'}
        else{Add-Result ERROR 'RCON secret coherence' 'BOIII and bridge secrets differ.' 'Run Configure_PinteMod_RCON.bat to regenerate one coherent pair.'}
    }

    if(Test-Path -LiteralPath $serverCfg){
        $serverText=Get-Content -LiteralPath $serverCfg -Raw
        if($serverText -match '(?im)^\s*exec\s+"?pintemod_server_secrets\.cfg"?\s*$'){Add-Result PASS 'server_zm secret include' 'pintemod_server_secrets.cfg is loaded.'}
        else{Add-Result ERROR 'server_zm secret include' 'Missing exec pintemod_server_secrets.cfg.' 'Run Configure_PinteMod_RCON.bat or add the exec line once.'}
    }

    if(Test-Path -LiteralPath $geoConfig){
        try{
            $gc=Get-Content -LiteralPath $geoConfig -Raw|ConvertFrom-Json
            $address=[string]$gc.server_address; $port=[int]$gc.server_port
            if([string]::IsNullOrWhiteSpace($address)){Add-Result ERROR 'RCON address' 'Empty server_address.' 'Set the BOIII server address.'}
            elseif(-not $RemoteToolsMachine -and $address -notin @('127.0.0.1','localhost','::1')){Add-Result WARNING 'RCON address' ("Local launcher points to $address.") 'Use 127.0.0.1 for same-machine deployment, or run the remote-tools launcher intentionally.'}
            else{Add-Result PASS 'RCON address' $address}
            if($port -ge 1 -and $port -le 65535){Add-Result PASS 'RCON port range' ([string]$port)}else{Add-Result ERROR 'RCON port range' ([string]$port) 'Use the BOIII net_port value.'}
            $runtimeNetPort=Get-RunningDedicatedNetPort
            $cfgNetPort=Get-NetPort $serverCfg
            $launcherNetPort=Get-NetPort $launcherCandidate
            $logNetPort=Get-RecentBoundNetPort $root
            $netPort=0
            $netPortSource=''
            if($runtimeNetPort -gt 0){$netPort=$runtimeNetPort;$netPortSource='running BOIII command line'}
            elseif($cfgNetPort -gt 0){$netPort=$cfgNetPort;$netPortSource='server_zm.cfg'}
            elseif($launcherNetPort -gt 0){$netPort=$launcherNetPort;$netPortSource=(Split-Path -Leaf $launcherCandidate)}
            elseif($logNetPort -gt 0){$netPort=$logNetPort;$netPortSource='recent BOIII log'}
            if($netPort -gt 0){
                if($netPort -eq $port){Add-Result PASS 'RCON/net_port coherence' ("Bridge=$port, $netPortSource=$netPort")}
                else{Add-Result ERROR 'RCON/net_port coherence' ("Bridge=$port, $netPortSource=$netPort") 'Set the bridge port to the active BOIII net_port value.'}
            }
            else{Add-Result WARNING 'RCON/net_port coherence' 'No authoritative net_port was available from the running server, configuration, launcher or recent logs.' 'Start BOIII and rerun Test_PinteMod_v2.1.1.bat, or declare +set net_port in Server.bat.'}
        }catch{Add-Result ERROR 'GeoIP local JSON' $_.Exception.Message 'Delete/recreate the local configuration.'}
    }
}

# Double instances
foreach($name in @('PinteMod_Server_Launcher.ps1','PinteMod_Ban_Service.ps1','PinteMod_GeoIP_Bridge.ps1','PinteMod_LiveConsole.ps1','PinteMod_Remote_Tools_Launcher.ps1')){
    $path=Join-Path $tools $name
    if(-not (Test-Path -LiteralPath $path)){continue}
    $processes=@(Get-RunningScriptProcesses $path)
    if($processes.Count -gt 1){Add-Result ERROR ('Double instance '+$name) ("$($processes.Count) processes found.") 'Close all copies and use one principal launcher.'}
    elseif($processes.Count -eq 1){Add-Result PASS ('Instance '+$name) 'One running process.'}
    else{Add-Result PASS ('Instance '+$name) 'Not currently running.'}
}

# Private/publication-risk files
$riskPatterns=@('*.local.json','*.secret.txt','*.dpapi','*.log','*.bak','*.tmp','bans.json','roles.json','players.json','records.json')
$risks=New-Object System.Collections.Generic.List[string]
foreach($pattern in $riskPatterns){foreach($f in @(Get-ChildItem -LiteralPath $root -Filter $pattern -File -Recurse -ErrorAction SilentlyContinue)){$risks.Add($f.FullName)|Out-Null}}
if(Test-Path -LiteralPath (Join-Path $boiii 'scriptdata')){$risks.Add((Join-Path $boiii 'scriptdata'))|Out-Null}
$risks=@($risks|Sort-Object -Unique)
if($PublicPackageAudit){
    if($risks.Count){Add-Result ERROR 'Public-file privacy scan' (($risks|Select-Object -First 20)-join '; ') 'Remove runtime data, logs, secrets, profiles and local JSON before packaging.'}
    else{Add-Result PASS 'Public-file privacy scan' 'No local/private runtime file found.'}
}else{
    if($risks.Count){Add-Result PASS 'Local/private runtime files' ("$($risks.Count) local/runtime paths detected; this is expected on a live server and they must remain local.") 'Do not copy these paths to GitHub or a public ZIP; publish only from a clean public package.'}
    else{Add-Result PASS 'Local/private runtime files' 'No current local/runtime file detected.'}
}

# Deep runtime/log checks
if($Deep -and -not $PublicPackageAudit){
    $healthRoot=Join-Path $scriptdata 'health'
    foreach($tool in @('supervisor','ban_service','geoip_bridge','live_console')){
        $path=Join-Path $healthRoot ($tool+'.json')
        if(Test-Path -LiteralPath $path){
            try{$hb=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json;$age=([DateTime]::UtcNow-[DateTime]::Parse([string]$hb.updated_utc).ToUniversalTime()).TotalSeconds
                if($age -le 15 -and $hb.state -in @('running','connected','monitoring','active')){Add-Result PASS ('Heartbeat '+$tool) ("state=$($hb.state), age=$([int]$age)s")}
                elseif($age -le 60){Add-Result WARNING ('Heartbeat '+$tool) ("state=$($hb.state), age=$([int]$age)s") 'Check whether the tool should currently be active.'}
                else{Add-Result ERROR ('Heartbeat '+$tool) ("Stale by $([int]$age)s") 'Restart the launcher/tool and inspect runtime logs.'}
            }catch{Add-Result ERROR ('Heartbeat '+$tool) $_.Exception.Message 'Delete the invalid heartbeat and restart the tool.'}
        }else{Add-Result WARNING ('Heartbeat '+$tool) 'No heartbeat file yet.' 'Start the complete launcher, then rerun the deep test.'}
    }
    $runtime=Join-Path $tools 'runtime'
    foreach($errFile in @(Get-ChildItem -LiteralPath $runtime -Filter '*.error.log' -File -ErrorAction SilentlyContinue)){
        if($errFile.Length -gt 0){Add-Result WARNING ('Runtime error log '+$errFile.Name) ("$($errFile.Length) bytes") 'Open the file and resolve the latest error before final validation.'}
    }
}

# Package version consistency
$versionFiles=@(
    $gsc
    Get-ChildItem -LiteralPath $tools -File -ErrorAction SilentlyContinue | Where-Object {$_.Extension -in @('.ps1','.bat','.json')}
    Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue | Where-Object {$_.Extension -eq '.bat'}
)
$oldRuntimeRefs=@()
foreach($f in $versionFiles){$t=Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue;if($t -match '(?i)PinteMod\s+v2\.1\.0|PinteMod_v2\.1\.0'){$oldRuntimeRefs+=$f.FullName}}
if($oldRuntimeRefs.Count){Add-Result WARNING 'Version consistency' (($oldRuntimeRefs|Select-Object -First 20)-join '; ') 'Review stale v2.1.0 release labels.'}
else{Add-Result PASS 'Version consistency' 'No stale v2.1.0 runtime label found.'}

# Write machine-readable report outside public source tree only when runtime is available.
# PowerShell 5.1 can throw "Argument types do not match" when @() wraps a generic List[object].
$reportResults=New-Object object[] $script:Results.Count
if($script:Results.Count -gt 0){$script:Results.CopyTo($reportResults)}
$report=[ordered]@{
    schema_version=1; tool='Verify_PinteMod_Installation'; version='2.1.1'; checked_utc=[DateTime]::UtcNow.ToString('o'); root=$root;
    pass=$script:PassCount; warning=$script:WarningCount; error=$script:ErrorCount; results=$reportResults
}
if(-not $PublicPackageAudit){
    try{
        $diag=Join-Path $scriptdata 'diagnostics'; if(-not(Test-Path -LiteralPath $diag)){New-Item -ItemType Directory -Path $diag -Force|Out-Null}
        $reportPath=Join-Path $diag 'installation_verification.json'
        [IO.File]::WriteAllText($reportPath,($report|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        Write-Host ('Report: '+$reportPath) -ForegroundColor DarkGray
    }catch{Write-Warning ('Unable to save diagnostic report: '+$_.Exception.Message)}
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor DarkCyan
Write-Host (" PASS=$script:PassCount  WARNING=$script:WarningCount  ERROR=$script:ErrorCount") -ForegroundColor $(if($script:ErrorCount){'Red'}elseif($script:WarningCount){'Yellow'}else{'Green'})
Write-Host '============================================================' -ForegroundColor DarkCyan
if($script:ErrorCount -gt 0){exit 2}
if($script:WarningCount -gt 0){exit 1}
exit 0
