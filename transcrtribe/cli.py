"""Command-line entry point for transcrtribe."""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn

from . import __version__
from .conversation import build_conversation, format_timestamp
from .diarizer import DiarizationUnavailable, assign_speakers, diarize
from .exporter import SUPPORTED_FORMATS, export
from .transcriber import transcribe

console = Console()

AUDIO_EXTENSIONS = {
    ".mp3", ".wav", ".m4a", ".flac", ".ogg", ".opus", ".aac", ".wma",
    ".mp4", ".mov", ".mkv", ".webm", ".3gp", ".aiff", ".aif",
}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="transcrtribe",
        description="Transcribe any audio/video file into a speaker-labeled, editable transcript "
        "(TXT, RTF, DOCX, PDF) using local Whisper AI.",
    )
    parser.add_argument("audio", nargs="+", help="Path(s) to audio or video file(s) to transcribe.")
    parser.add_argument(
        "-o", "--output-dir", default=".", help="Directory to write transcripts to (default: current directory)."
    )
    parser.add_argument(
        "-f", "--formats", default="txt,pdf",
        help=f"Comma-separated export formats: {', '.join(SUPPORTED_FORMATS)} (default: txt,pdf).",
    )
    parser.add_argument(
        "-m", "--model", default="small",
        help="Whisper model size: tiny, base, small, medium, large-v3 (default: small).",
    )
    parser.add_argument("-l", "--language", default=None, help="Force a language code (default: auto-detect).")
    parser.add_argument(
        "-s", "--speakers", type=int, default=None,
        help="Exact number of speakers, if known (improves diarization accuracy).",
    )
    parser.add_argument(
        "--hf-token", default=None,
        help="Hugging Face access token for speaker diarization (or set HF_TOKEN env var).",
    )
    parser.add_argument(
        "--no-diarization", action="store_true",
        help="Skip speaker recognition and produce a plain transcript.",
    )
    parser.add_argument("--device", default="auto", choices=["auto", "cpu", "cuda", "mps"])
    parser.add_argument("--version", action="version", version=f"transcrtribe {__version__}")
    return parser


def process_file(audio_path: Path, args: argparse.Namespace) -> None:
    console.rule(f"[bold cyan]{audio_path.name}")

    with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=console) as progress:
        task = progress.add_task("Transcribing with Whisper AI...", total=None)
        segments, language = transcribe(
            str(audio_path), model_size=args.model, language=args.language, device=args.device
        )
        progress.update(task, description=f"Transcribed ({language}) — {len(segments)} segments")

    turns_source = segments
    if not args.no_diarization:
        try:
            with Progress(SpinnerColumn(), TextColumn("[progress.description]{task.description}"), console=console) as progress:
                task = progress.add_task("Identifying speakers...", total=None)
                speaker_turns = diarize(
                    str(audio_path), hf_token=args.hf_token, num_speakers=args.speakers, device=args.device
                )
                assign_speakers(segments, speaker_turns)
                progress.update(task, description=f"Identified {len({t.speaker for t in speaker_turns})} speaker(s)")
        except DiarizationUnavailable as exc:
            console.print(f"[yellow]Speaker recognition skipped:[/yellow] {exc}")
            for seg in segments:
                seg.speaker = "Speaker 1"
    else:
        for seg in segments:
            seg.speaker = "Speaker 1"

    conversation = build_conversation(turns_source)

    console.print()
    for turn in conversation[:5]:
        console.print(f"[bold]{format_timestamp(turn.start)} {turn.speaker}:[/bold] {turn.text}")
    if len(conversation) > 5:
        console.print(f"[dim]... {len(conversation) - 5} more turn(s) ...[/dim]")
    console.print()

    output_dir = Path(args.output_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    output_base = output_dir / audio_path.stem
    formats = [f.strip().lower() for f in args.formats.split(",") if f.strip()]

    written = export(conversation, output_base, formats, title=audio_path.stem)
    for path in written:
        console.print(f"[green]Wrote[/green] {path}")


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    formats = [f.strip().lower() for f in args.formats.split(",") if f.strip()]
    for fmt in formats:
        if fmt not in SUPPORTED_FORMATS:
            parser.error(f"Unsupported format '{fmt}'. Choose from: {', '.join(SUPPORTED_FORMATS)}")

    exit_code = 0
    for audio_arg in args.audio:
        audio_path = Path(audio_arg).expanduser().resolve()
        if not audio_path.exists():
            console.print(f"[red]File not found:[/red] {audio_path}")
            exit_code = 1
            continue
        try:
            process_file(audio_path, args)
        except Exception as exc:  # keep going for remaining files
            console.print(f"[red]Failed to process {audio_path.name}:[/red] {exc}")
            exit_code = 1

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
