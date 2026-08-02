@echo off
setlocal
title PinteMod v2.1.1 - Verification de l'installation
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0boiii\tools\Verify_PinteMod_Installation.ps1" -ServerRoot "%~dp0" %*
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" echo [PinteMod] Verification terminee sans avertissement.
if "%RC%"=="1" echo [PinteMod] Verification terminee avec avertissement(s).
if "%RC%"=="2" echo [PinteMod] Verification terminee avec erreur(s).
pause
endlocal & exit /b %RC%
