@echo off
setlocal
title PinteMod v2.1.1 - Configure RCON
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0boiii\tools\Configure_PinteMod_Server_Secrets.ps1" -ServerRoot "%~dp0" %*
if errorlevel 1 (
    echo.
    echo PinteMod RCON configuration stopped with an error.
    pause
)
endlocal
