@echo off
setlocal
title PinteMod v2.1.1 - GeoIP Language Bridge
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0PinteMod_GeoIP_Bridge.ps1" %*
if errorlevel 1 (
    echo.
    echo PinteMod GeoIP Bridge stopped with an error.
    pause
)
endlocal
