$ErrorActionPreference = "Stop"

$LauncherBat = Join-Path $env:USERPROFILE ".transcrtribe\bin\transcrtribe.bat"

if (-not (Test-Path $LauncherBat)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "transcrtribe is not installed. Run 'Install Transcrtribe.bat' first.",
        "transcrtribe", "OK", "Error"
    ) | Out-Null
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = "Choose an audio or video file to transcribe"
$dialog.Filter = "Audio/Video files|*.mp3;*.wav;*.m4a;*.flac;*.ogg;*.opus;*.aac;*.wma;*.mp4;*.mov;*.mkv;*.webm;*.aiff;*.aif|All files|*.*"

if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "No file selected. Exiting."
    exit 0
}
$File = $dialog.FileName

$OutputDir = Join-Path ([Environment]::GetFolderPath("Desktop")) "Transcrtribe Output"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-Host "Transcribing: $File"
Write-Host "Output folder: $OutputDir"
Write-Host ""

& $LauncherBat "$File" -o "$OutputDir" -f txt,rtf,docx,pdf

Write-Host ""
Write-Host "Done! Opening output folder..."
Start-Process explorer.exe "$OutputDir"

Read-Host "Press Enter to close this window"
