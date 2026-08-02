@echo off
setlocal
title PinteMod v2.1.1 - Live Console
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0PinteMod_LiveConsole.ps1" %*
if errorlevel 1 (
    echo.
    echo PinteMod Live Console stopped with an error.
    pause
)
endlocal
