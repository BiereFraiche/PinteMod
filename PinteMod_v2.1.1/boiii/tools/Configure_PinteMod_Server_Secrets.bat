@echo off
setlocal
title PinteMod v2.1.1 - Configuration RCON persistante
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Configure_PinteMod_Server_Secrets.ps1" %*
if errorlevel 1 (
    echo.
    echo La configuration PinteMod a echoue.
    pause
    exit /b 1
)
echo.
echo Configuration terminee. Redemarrez completement le serveur BOIII.
pause
endlocal
