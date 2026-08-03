@echo off
setlocal
title PinteMod v2.1.1 - Remote Tools
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0boiii\tools\PinteMod_Remote_Tools_Launcher.ps1" %*
if errorlevel 1 (
    echo.
    echo PinteMod remote tools launcher stopped with an error.
    pause
)
endlocal
