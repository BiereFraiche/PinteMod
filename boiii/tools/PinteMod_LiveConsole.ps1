@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0PinteMod_Remote_Control.ps1"
if errorlevel 1 (
  echo.
  echo PinteMod Remote Control could not start.
  echo Read the error above, then press a key.
  pause >nul
)
endlocal
