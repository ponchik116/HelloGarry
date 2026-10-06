@echo off
setlocal
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0install.ps1"
if errorlevel 1 (
  echo.
  echo Installation failed. See the message above.
  pause
  exit /b 1
)
pause
