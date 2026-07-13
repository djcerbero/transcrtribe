@echo off
REM Double-click this file in Explorer to pick an audio/video file and
REM transcribe it. No terminal knowledge required.
setlocal
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%transcribe_audio_windows.ps1"
