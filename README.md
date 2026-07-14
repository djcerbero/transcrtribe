# transcrtribe

Local, private speech-to-text for **macOS and Windows**. Drop in any audio or
video file and get back an editable, speaker-labeled transcript — like a
script of the conversation — in TXT, RTF, DOCX and/or PDF. Powered by
OpenAI's Whisper model (via `faster-whisper`) running entirely on your
machine, plus `pyannote.audio` for "who said what" speaker recognition.
Audio is automatically loudness-normalized before processing to improve
accuracy on quiet or unevenly-recorded files.

## Install

### macOS

1. Download/clone this folder.
2. Double-click **`Install Transcrtribe.command`**.
   - It installs Homebrew, Python 3 and ffmpeg if you don't already have them,
     creates an isolated environment in `~/.transcrtribe`, and installs the
     `transcrtribe` command.
3. Open a **new** Terminal window (or just use the double-click app below).

If Finder refuses to run the `.command` file ("cannot be opened because it
is from an unidentified developer"), right-click it and choose **Open**
once — that permanently whitelists it.

### Windows

1. Download/clone this folder.
2. Double-click **`Install Transcrtribe.bat`**.
   - It installs Python 3 and ffmpeg via `winget` if you don't already have
     them, creates an isolated environment in `%USERPROFILE%\.transcrtribe`,
     and installs the `transcrtribe` command.
3. Open a **new** PowerShell or `cmd` window (or just use the double-click
   app below).

The `.bat` launches the real installer (`install_windows.ps1`) with a
scoped `-ExecutionPolicy Bypass`, so it works even though PowerShell scripts
are disabled by default on a fresh Windows install — you don't need to
change any system-wide execution policy yourself.

If `winget` isn't available (older Windows 10 builds without "App
Installer"), the script tells you so and points you to
https://www.python.org/downloads/windows/ — install Python with **"Add
python.exe to PATH"** checked, then re-run the installer.

That's it — no manual pip installs, no PATH editing on either platform.

## Use it

### Easiest: double-click app
- **macOS**: double-click **`Transcribe Audio.command`**.
- **Windows**: double-click **`Transcribe Audio.bat`**.

Either one opens a native file picker, transcribes the file, and opens the
finished transcripts in a `Transcrtribe Output` folder on your Desktop when
done.

### Terminal / PowerShell / cmd
```bash
transcrtribe meeting.mp3
transcrtribe interview.m4a -o ~/Documents/Transcripts -f txt,docx,pdf
transcrtribe call.wav --speakers 2          # tell it exactly how many people spoke
transcrtribe podcast.mp4 -m medium           # bigger model = more accurate, slower
```

(On Windows, use a Windows-style path, e.g. `transcrtribe C:\Users\you\meeting.mp3`.)

Supports basically any audio or video container: mp3, wav, m4a, flac, ogg,
opus, aac, mp4, mov, mkv, webm, and more.

## Speaker recognition ("who said what")

Speaker diarization uses `pyannote.audio`'s pretrained pipeline, which requires
a free Hugging Face account:

1. Create a token at https://huggingface.co/settings/tokens (read access is enough).
2. Accept the model terms at https://huggingface.co/pyannote/speaker-diarization-3.1
   and https://huggingface.co/pyannote/segmentation-3.0.
3. Set it once:
   - **macOS**:
     ```bash
     echo 'export HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxx' >> ~/.zshrc
     ```
   - **Windows** (PowerShell or cmd):
     ```
     setx HF_TOKEN hf_xxxxxxxxxxxxxxxxxxxx
     ```
4. Open a new terminal/PowerShell window and run `transcrtribe` as usual.

If no token is configured, transcrtribe still works — it just labels
everything as a single speaker instead of failing. It never crashes for
this reason; you'll just see a yellow "speaker recognition skipped" note.

## Output format

Each turn in the conversation is written as:

```
[00:00] Speaker 1: Hey, how's it going?

[00:03] Speaker 2: Pretty good, thanks for asking!
```

All exported formats (TXT, RTF, DOCX, PDF) are fully editable in TextEdit,
Notepad, Word, Pages, Preview, etc. — on both platforms.

## Options

```
transcrtribe --help
```

| Flag | Description |
|---|---|
| `-o, --output-dir` | Where to write transcripts (default: current directory) |
| `-f, --formats` | Comma-separated: `txt,rtf,docx,pdf` (default: `txt,pdf`) |
| `-m, --model` | Whisper model: `tiny`, `base`, `small`, `medium`, `large-v3` (default: `small`) |
| `-l, --language` | Force a language code instead of auto-detect |
| `-s, --speakers` | Exact number of speakers, if known |
| `--hf-token` | Pass a Hugging Face token directly instead of via `HF_TOKEN` |
| `--no-diarization` | Skip speaker recognition entirely |
| `--device` | `auto`, `cpu`, `cuda`, or `mps` (Apple Silicon GPU; ignored/no-op on Windows and Intel Macs) |
| `--compute-type` | faster-whisper compute type: `default`, `int8`, `int8_float16`, `float16`, `float32`. Use `int8` on CPU for faster inference and to silence the float16-unsupported warning |

## Uninstall

- **macOS**:
  ```bash
  rm -rf ~/.transcrtribe ~/.local/bin/transcrtribe
  ```
- **Windows** (PowerShell):
  ```powershell
  Remove-Item -Recurse -Force "$env:USERPROFILE\.transcrtribe"
  ```
  Then remove `%USERPROFILE%\.transcrtribe\bin` from your user PATH via
  System Properties → Environment Variables (the installer only appends to
  it, it never overwrites your existing PATH).

## Manual install (any OS, or if you prefer plain pip)

```bash
pip install .
transcrtribe --help
```

## Troubleshooting notes

- **"cannot verify the developer" (macOS) / "Windows protected your PC"
  (Windows SmartScreen)**: these are standard unsigned-script warnings, not
  errors in the app. Right-click → Open (macOS) or "More info" → "Run
  anyway" (Windows) once.
- **PowerShell "running scripts is disabled on this system"**: only happens
  if you try to run `install_windows.ps1` directly instead of the `.bat`
  wrapper. Always launch via `Install Transcrtribe.bat` /
  `Transcribe Audio.bat`, which apply the bypass automatically without
  touching your machine's global execution policy.
- **Output folder doesn't exist yet**: the CLI creates `-o`'s directory
  (and any parents) automatically — you never need to `mkdir` it yourself.
- **`403 Forbidden` while transcribing/diarizing**: transcrtribe downloads
  Whisper/pyannote model weights from `huggingface.co` on first use. This
  error means something between you and Hugging Face (corporate firewall,
  VPN, or a restrictive sandbox) is blocking that host — it isn't a bug in
  the app. Retry on a normal network connection.
- **`No matching distribution found for torch`**: PyTorch only ships wheels
  for Python versions the whole ML ecosystem has caught up to. Both
  installers avoid this by pinning to Python 3.12 for transcrtribe's own
  isolated environment (macOS via `python@3.12` from Homebrew, Windows via
  `winget`/the `py` launcher) regardless of what your system's default
  `python3` is — so this shouldn't come up. If you hit it anyway, make sure
  you're running the current `Install Transcrtribe.command`/`.bat`, not an
  older copy, and re-run the installer.
