# transcrtribe

Local, private speech-to-text for macOS. Drop in any audio or video file and
get back an editable, speaker-labeled transcript — like a script of the
conversation — in TXT, RTF, DOCX and/or PDF. Powered by OpenAI's Whisper
model (via `faster-whisper`) running entirely on your machine, plus
`pyannote.audio` for "who said what" speaker recognition. Audio is
automatically loudness-normalized before processing to improve accuracy on
quiet or unevenly-recorded files.

## Install (macOS)

1. Download/clone this folder.
2. Double-click **`Install Transcrtribe.command`**.
   - It installs Homebrew, Python 3 and ffmpeg if you don't already have them,
     creates an isolated environment in `~/.transcrtribe`, and installs the
     `transcrtribe` command.
3. Open a **new** Terminal window (or just use the double-click app below).

That's it — no manual pip installs, no PATH editing.

## Use it

### Easiest: double-click app
Double-click **`Transcribe Audio.command`**. It opens a file picker, transcribes
the file, and opens the finished transcripts on your Desktop when done.

### Terminal
```bash
transcrtribe meeting.mp3
transcrtribe interview.m4a -o ~/Documents/Transcripts -f txt,docx,pdf
transcrtribe call.wav --speakers 2          # tell it exactly how many people spoke
transcrtribe podcast.mp4 -m medium           # bigger model = more accurate, slower
```

Supports basically any audio or video container: mp3, wav, m4a, flac, ogg,
opus, aac, mp4, mov, mkv, webm, and more.

## Speaker recognition ("who said what")

Speaker diarization uses `pyannote.audio`'s pretrained pipeline, which requires
a free Hugging Face account:

1. Create a token at https://huggingface.co/settings/tokens (read access is enough).
2. Accept the model terms at https://huggingface.co/pyannote/speaker-diarization-3.1
   and https://huggingface.co/pyannote/segmentation-3.0.
3. Set it once in your shell profile:
   ```bash
   echo 'export HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxx' >> ~/.zshrc
   ```
4. Open a new terminal and run `transcrtribe` as usual.

If no token is configured, transcrtribe still works — it just labels
everything as a single speaker instead of failing.

## Output format

Each turn in the conversation is written as:

```
[00:00] Speaker 1: Hey, how's it going?

[00:03] Speaker 2: Pretty good, thanks for asking!
```

All exported formats (TXT, RTF, DOCX, PDF) are fully editable in TextEdit,
Word, Pages, Preview, etc.

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
| `--device` | `auto`, `cpu`, `cuda`, or `mps` (Apple Silicon GPU) |

## Uninstall

```bash
rm -rf ~/.transcrtribe ~/.local/bin/transcrtribe
```

## Manual (non-macOS) install

```bash
pip install .
transcrtribe --help
```
