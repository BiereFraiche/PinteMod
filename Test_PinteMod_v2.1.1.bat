@echo off
setlocal
title PinteMod v2.1.1 - Test global Windows
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0boiii\tools\Verify_PinteMod_Installation.ps1" -ServerRoot "%~dp0" -Deep %*
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" echo [PinteMod] Test Windows global : PASS.
if "%RC%"=="1" echo [PinteMod] Test Windows global : PASS avec avertissement(s) a examiner.
if "%RC%"=="2" echo [PinteMod] Test Windows global : FAIL. Corrigez les erreurs avant le test serveur.
pause
endlocal & exit /b %RC%
