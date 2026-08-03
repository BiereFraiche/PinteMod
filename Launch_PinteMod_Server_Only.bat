@echo off
setlocal
title PinteMod v2.1.1 - Server Only
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0boiii\tools\PinteMod_Server_Launcher.ps1" -PackageRoot "%~dp0" -ServerOnly %*
if errorlevel 1 (
    echo.
    echo PinteMod server-only launcher stopped with an error.
    pause
)
endlocal
