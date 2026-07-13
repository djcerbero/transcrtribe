#Requires -Version 5.1
# transcrtribe installer for Windows.
# Sets up an isolated Python environment and installs the `transcrtribe` CLI
# so it can be run from any new terminal (PowerShell or cmd).

$ErrorActionPreference = "Stop"

function Info($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "==> $msg" -ForegroundColor Green }
function WarnMsg($msg) { Write-Host "==> $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "  transcrtribe installer (Windows)"
Write-Host "  --------------------------------"
Write-Host ""

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppDir  = Join-Path $env:USERPROFILE ".transcrtribe"
$VenvDir = Join-Path $AppDir "venv"
$BinDir  = Join-Path $AppDir "bin"

# 1. Locate (or install) Python 3.9+
function Find-Python {
    foreach ($cmd in @("python", "python3")) {
        $found = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($found) {
            try {
                $verOut = & $cmd --version 2>&1
                if ($verOut -match "Python 3\.(\d+)" -and [int]$Matches[1] -ge 9) {
                    return $cmd
                }
            } catch {}
        }
    }
    return $null
}

$PythonCmd = Find-Python

if (-not $PythonCmd) {
    Info "Python 3 not found."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Info "Installing Python via winget..."
        winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
        # Refresh PATH for the current process so the new install is visible immediately.
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $PythonCmd = Find-Python
    }
    if (-not $PythonCmd) {
        Write-Host ""
        Write-Host "Could not find or install Python automatically." -ForegroundColor Red
        Write-Host "Please install Python 3.9+ from https://www.python.org/downloads/windows/" -ForegroundColor Red
        Write-Host "  IMPORTANT: check 'Add python.exe to PATH' during setup." -ForegroundColor Red
        Write-Host "Then re-run this installer." -ForegroundColor Red
        exit 1
    }
}
Info "Using Python: $PythonCmd ($(& $PythonCmd --version))"

# 2. ffmpeg (broadens audio/video format support beyond the bundled decoder)
$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpeg) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Info "Installing ffmpeg via winget..."
        try {
            winget install -e --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements
        } catch {
            WarnMsg "ffmpeg install failed or was skipped; most common formats still work without it."
        }
    } else {
        WarnMsg "ffmpeg not found and winget is unavailable. Most formats still work; for full format coverage install ffmpeg manually from https://ffmpeg.org/download.html"
    }
} else {
    Info "ffmpeg found."
}

# 3. Virtual environment
Info "Creating isolated environment at $VenvDir ..."
New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
& $PythonCmd -m venv $VenvDir

$VenvPython = Join-Path $VenvDir "Scripts\python.exe"
$VenvExe    = Join-Path $VenvDir "Scripts\transcrtribe.exe"

Info "Installing transcrtribe and dependencies (this can take a few minutes)..."
& $VenvPython -m pip install --upgrade pip --quiet
& $VenvPython -m pip install "$RepoDir" --quiet

if (-not (Test-Path $VenvExe)) {
    Write-Host "Installation failed: transcrtribe.exe was not created." -ForegroundColor Red
    exit 1
}

# 4. Launcher on PATH
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$LauncherBat = Join-Path $BinDir "transcrtribe.bat"
@"
@echo off
"$VenvExe" %*
"@ | Set-Content -Encoding ASCII $LauncherBat

# 5. Add launcher folder to the user's PATH (once)
$currentUserPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($currentUserPath -notlike "*$BinDir*") {
    $newPath = if ($currentUserPath) { "$currentUserPath;$BinDir" } else { $BinDir }
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Info "Added $BinDir to your user PATH."
}
$env:Path = "$env:Path;$BinDir"

Ok "Installation complete!"
Write-Host ""
Write-Host "  Open a NEW terminal window (PowerShell or cmd), then run:"
Write-Host ""
Write-Host "      transcrtribe path\to\audio.mp3"
Write-Host ""
Write-Host "  For speaker recognition (who said what), set a free Hugging Face token once:"
Write-Host ""
Write-Host "      setx HF_TOKEN hf_xxxxxxxxxxxx"
Write-Host ""
Write-Host "  Get one at https://huggingface.co/settings/tokens and accept the model terms at"
Write-Host "  https://huggingface.co/pyannote/speaker-diarization-3.1"
Write-Host ""
Write-Host "  Run 'transcrtribe --help' to see all options."
Write-Host ""
