@echo off
setlocal
title PinteMod v2.1.1 - Ban Service
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0PinteMod_Ban_Service.ps1" %*
if errorlevel 1 (
    echo.
    echo PinteMod Ban Service stopped with an error.
    pause
)
endlocal
