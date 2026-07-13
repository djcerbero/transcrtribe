@echo off
REM Double-click this file in Explorer to install transcrtribe.
REM Runs the PowerShell installer with a scoped, one-time execution-policy
REM bypass so it works even on machines where PowerShell scripts are
REM disabled by default (the out-of-the-box Windows setting).
setlocal
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install_windows.ps1"
echo.
pause
