@echo off
setlocal
set "PINTEMOD_PACKAGE_ROOT=%~dp0"
set "PINTEMOD_RUNTIME=%~dp0boiii\tools\runtime"
set "PINTEMOD_LAUNCHER=%~dp0boiii\tools\PinteMod_Server_Launcher.ps1"
if not exist "%PINTEMOD_RUNTIME%" mkdir "%PINTEMOD_RUNTIME%" >nul 2>&1

title PinteMod v2.1.1
if not exist "%PINTEMOD_LAUNCHER%" (
    echo [PinteMod] Lanceur PowerShell introuvable :
    echo %PINTEMOD_LAUNCHER%
    pause
    endlocal & exit /b 1
)

set "PINTEMOD_SETUP_REQUIRED="
for %%F in (
    "%~dp0boiii\tools\PinteMod_Server_Launcher.local.json"
    "%~dp0boiii\tools\PinteMod_GeoIP_Bridge.local.json"
    "%~dp0boiii\tools\PinteMod_GeoIP_Bridge.secret.txt"
    "%~dp0zone\pintemod_server_secrets.cfg"
    "%~dp0zone\server_zm.cfg"
) do if not exist "%%~F" set "PINTEMOD_SETUP_REQUIRED=1"

if defined PINTEMOD_SETUP_REQUIRED (
    echo ============================================================
    echo  PinteMod v2.1.1 - configuration initiale
    echo ============================================================
    echo Une configuration locale manque. Le superviseur reste visible
    echo pour permettre les questions de configuration et afficher toute erreur.
    echo Les lancements suivants seront discrets une fois la configuration creee.
    echo.
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PINTEMOD_LAUNCHER%" -PackageRoot "%PINTEMOD_PACKAGE_ROOT%"
    if errorlevel 1 (
        pause
        endlocal & exit /b 1
    )
    endlocal & exit /b 0
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$root=$env:PINTEMOD_PACKAGE_ROOT; $runtime=$env:PINTEMOD_RUNTIME; $script=$env:PINTEMOD_LAUNCHER; $out=Join-Path $runtime 'PinteMod_Supervisor.bootstrap.out.log'; $err=Join-Path $runtime 'PinteMod_Supervisor.bootstrap.error.log'; Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue; $arguments=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$script+'"'),'-PackageRoot',('"'+$root+'"')); $p=Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err -PassThru; Start-Sleep -Seconds 2; $p.Refresh(); if($p.HasExited -and $p.ExitCode -ne 0){ if(Test-Path -LiteralPath $err){ Get-Content -LiteralPath $err -Tail 30 }; exit $p.ExitCode }"
if errorlevel 1 (
    echo.
    echo [PinteMod] Le superviseur n'a pas pu demarrer.
    echo Consultez : boiii\tools\runtime\PinteMod_Supervisor.bootstrap.error.log
    pause
    endlocal & exit /b 1
)

echo [PinteMod] Demarrage lance. BOIII et la Live Console vont s'ouvrir.
echo [PinteMod] Le superviseur fonctionne en arriere-plan.
echo [PinteMod] Journal : boiii\tools\runtime\PinteMod_Supervisor.log
timeout /t 2 /nobreak >nul
endlocal & exit /b 0
