@echo off
chcp 65001 >nul
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 (
  echo.
  echo Установка завершилась с ошибкой.
  pause
  exit /b 1
)
echo.
echo Готово. Нажми любую клавишу.
pause >nul
