# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`transcrtribe` is a local, offline-first CLI that transcribes any audio/video
file with Whisper AI, identifies speakers, and exports an editable
conversation-style transcript. It ships as a pip-installable Python package
plus double-click installers/launchers for both macOS and Windows (no
separate "app" codebase — the `.command`/`.bat`/`.ps1` files just shell out
to the installed CLI).

## Commands

```bash
# Install in editable mode for development
pip install -e .

# Run the CLI
transcrtribe <audio_or_video_file> [options]
python -m transcrtribe.cli <file>   # equivalent, without installing the entry point

# Key flags
transcrtribe file.mp3 -o out_dir -f txt,rtf,docx,pdf -m small --speakers 2 --no-diarization --device auto
```

There is no test suite, linter, or CI config in this repo yet. There is no
build step beyond standard `pip`/`setuptools` packaging (`pyproject.toml`,
setuptools backend, single package `transcrtribe`).

When verifying changes manually, the pipeline can be exercised in stages
without needing real speech audio or a Hugging Face token:
- `transcriber.transcribe()` requires downloading a Whisper model from
  Hugging Face on first run (network-gated — blocked in some sandboxes).
- `diarizer.diarize()` requires an `HF_TOKEN`/`HUGGINGFACE_TOKEN` env var and
  accepted model terms for `pyannote/speaker-diarization-3.1`; without it,
  it raises `DiarizationUnavailable` by design (see Architecture below).
- `conversation.build_conversation()` and `exporter.export()` have no
  external dependencies and can be smoke-tested directly with synthetic
  `Segment`/`ConversationTurn` objects.

## Architecture

The pipeline is a straight-line sequence of five independent stages, each in
its own module under `transcrtribe/`, orchestrated by `cli.py`:

1. **`audio_prep.py`** — runs the input file through `ffmpeg`'s EBU R128
   `loudnorm` filter (speech preset, single-pass) before transcription/
   diarization, writing a normalized mono 16kHz temp WAV. This is the other
   stage allowed to fail loudly-but-safely: it raises
   `NormalizationUnavailable` (not a crash) if `ffmpeg` is missing or the
   conversion fails, and `cli.py` catches that specifically to fall back to
   the original, un-normalized file. Always on — no CLI flag to disable it.
   `cli.py` owns deleting the temp file once processing finishes.

2. **`transcriber.py`** — wraps `faster_whisper.WhisperModel`. Produces a
   list of `Segment` (sentence-level, with word-level `Word` timestamps) and
   the detected language. Device selection (`cpu`/`cuda`) auto-detects via
   `_pick_device()`.

3. **`diarizer.py`** — wraps `pyannote.audio`'s pretrained pipeline
   (`pyannote/speaker-diarization-3.1`) to produce `SpeakerTurn` objects
   (start/end/speaker label). This is another stage allowed to fail
   loudly-but-safely: it raises `DiarizationUnavailable` (not a crash) when
   there's no HF token or pyannote can't load, and `cli.py` catches that
   specifically to fall back to labeling everything `"Speaker 1"`. Don't
   change this to a bare `except Exception` in the CLI — the intent is that
   *only* the expected/documented failure mode degrades gracefully; other
   exceptions from this stage should still surface.
   `assign_speakers(segments, turns)` then mutates `Segment.speaker` in
   place by picking the diarization turn with maximum time overlap per
   segment (falling back to nearest-turn-by-midpoint if no overlap exists).

4. **`conversation.py`** — `build_conversation()` collapses consecutive
   same-speaker `Segment`s into merged `ConversationTurn`s (this is what
   makes the output read like a script rather than a flat segment dump).
   `format_timestamp()` is the single source of truth for `MM:SS`/`H:MM:SS`
   formatting, shared by every exporter.

5. **`exporter.py`** — takes `ConversationTurn`s and writes TXT, RTF, DOCX,
   and/or PDF, all from the same data with no format-specific business
   logic elsewhere. Each format is a private `_export_<fmt>()` function;
   `SUPPORTED_FORMATS` is the single list gating both CLI `--formats`
   validation and dispatch in `export()` — keep them in sync if adding a
   format.

`cli.py` ties it together per input file: normalize audio (fall back to
original on failure) → transcribe → (try diarize, catch
`DiarizationUnavailable`) → assign speakers → build conversation → export.
Multiple input files are processed independently in a loop; one file's
failure doesn't stop the rest (see `main()`'s per-file try/except and
non-zero exit code accumulation).

### Distribution layer (macOS + Windows)

Both platforms follow the same three-file pattern: a real installer script,
a double-click wrapper for it, and a double-click "pick a file and
transcribe" launcher. Neither platform's installer touches the system
Python or global site-packages — each creates its own isolated venv.

**macOS:**
- `install_macos.sh` — idempotent installer: installs Homebrew/Python/ffmpeg
  if absent, creates a venv at `~/.transcrtribe/venv`, pip-installs the
  package into it, and writes a thin wrapper script to
  `~/.local/bin/transcrtribe` (added to PATH via `.zshrc`/`.bash_profile`).
- `Install Transcrtribe.command` — double-clickable Finder entry point that
  `cd`s to the repo and runs `install_macos.sh`.
- `Transcribe Audio.command` — no-terminal-required flow: native `osascript`
  file picker → runs `~/.local/bin/transcrtribe` → writes output to
  `~/Desktop/Transcrtribe Output` → reveals it in Finder.

**Windows:**
- `install_windows.ps1` — installs Python/ffmpeg via `winget` if absent
  (falling back to a manual-install message pointing at python.org if
  `winget` itself is missing), creates a venv at
  `%USERPROFILE%\.transcrtribe\venv`, pip-installs the package, and writes
  `%USERPROFILE%\.transcrtribe\bin\transcrtribe.bat` (a thin wrapper around
  the venv's `Scripts\transcrtribe.exe`). That `bin` folder is appended
  (never overwritten) to the user's `Path` via
  `[Environment]::SetEnvironmentVariable(..., "User")`.
- `Install Transcrtribe.bat` — double-clickable Explorer entry point. It
  invokes `install_windows.ps1` via
  `powershell -ExecutionPolicy Bypass -File ...` — a **scoped**, one-time
  bypass, not a system-wide policy change — so it works even on machines
  where PowerShell's default `Restricted` execution policy would otherwise
  block the `.ps1` from running at all.
- `Transcribe Audio.bat` → `transcribe_audio_windows.ps1` — same
  no-terminal flow as macOS, using `System.Windows.Forms.OpenFileDialog`
  for the file picker and writing to `Desktop\Transcrtribe Output`.

`.bat`/`.ps1` files are committed with CRLF line endings and `.command`/`.sh`
with LF, enforced via `.gitattributes` — don't let an editor or `git config
core.autocrlf` silently flip these; mixed line endings can break `cmd.exe`'s
batch parser in subtle ways.

If you change the CLI's argument surface (flags, defaults, output
directory conventions), update **both** `Transcribe Audio.command` and
`transcribe_audio_windows.ps1`'s invocation, plus the README's flag table —
none of these are derived from `cli.py` automatically.

## Known environment constraints

- Model downloads (Whisper weights via `faster-whisper`, pyannote
  pipelines) require reaching `huggingface.co`. Some sandboxed dev
  environments (and corporate networks/VPNs on end-user machines) block
  this host at the network policy level — that shows up as
  `403 Forbidden` during `transcribe()`/`diarize()`, not a code bug. Prefer
  testing `conversation.py`/`exporter.py` directly with synthetic data when
  working in such an environment; there's no way to exercise the real
  model-download path without outbound access to Hugging Face.
- `install_windows.ps1` and `transcribe_audio_windows.ps1` can't be syntax
  validated with `pwsh`/`powershell` in a Linux sandbox (no PowerShell
  runtime available there) — review changes to them carefully by hand, and
  actually double-click-test on a real Windows machine before trusting a
  change to this layer.
