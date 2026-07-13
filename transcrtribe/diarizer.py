"""Speaker diarization backed by pyannote.audio, with a safe single-speaker fallback."""
from __future__ import annotations

import os
import sys
from dataclasses import dataclass


@dataclass
class SpeakerTurn:
    start: float
    end: float
    speaker: str


class DiarizationUnavailable(Exception):
    pass


def diarize(
    audio_path: str,
    hf_token: str | None = None,
    num_speakers: int | None = None,
    device: str = "auto",
) -> list[SpeakerTurn]:
    """Return speaker turns for the audio file.

    Raises DiarizationUnavailable if pyannote isn't installed or no HF token is
    configured, so callers can fall back to a single-speaker transcript instead
    of crashing.
    """
    token = hf_token or os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_TOKEN")
    if not token:
        raise DiarizationUnavailable(
            "No Hugging Face token found. Set HF_TOKEN to enable speaker recognition "
            "(see README for setup); continuing without speaker labels."
        )

    try:
        from pyannote.audio import Pipeline
    except Exception as exc:  # pragma: no cover - import guard
        raise DiarizationUnavailable(f"pyannote.audio is not available: {exc}") from exc

    if device == "auto":
        device = _pick_device()

    pipeline = Pipeline.from_pretrained(
        "pyannote/speaker-diarization-3.1", use_auth_token=token
    )

    try:
        import torch

        pipeline.to(torch.device(device))
    except Exception:
        pass

    kwargs = {}
    if num_speakers:
        kwargs["num_speakers"] = num_speakers

    diarization = pipeline(audio_path, **kwargs)

    turns: list[SpeakerTurn] = []
    for segment, _, label in diarization.itertracks(yield_label=True):
        turns.append(SpeakerTurn(start=segment.start, end=segment.end, speaker=_friendly_name(label)))
    return turns


def _friendly_name(label: str) -> str:
    if label.upper().startswith("SPEAKER_"):
        try:
            idx = int(label.split("_")[-1])
            return f"Speaker {idx + 1}"
        except ValueError:
            pass
    return label


def _pick_device() -> str:
    try:
        import torch

        if torch.cuda.is_available():
            return "cuda"
        if torch.backends.mps.is_available():
            return "mps"
    except Exception:
        pass
    return "cpu"


def assign_speakers(segments, turns: list[SpeakerTurn]) -> None:
    """Mutate `segments` in place, setting `.speaker` to the best-overlapping turn."""
    if not turns:
        for seg in segments:
            seg.speaker = "Speaker 1"
        return

    for seg in segments:
        best_speaker = None
        best_overlap = 0.0
        for turn in turns:
            overlap = min(seg.end, turn.end) - max(seg.start, turn.start)
            if overlap > best_overlap:
                best_overlap = overlap
                best_speaker = turn.speaker
        seg.speaker = best_speaker or _nearest_speaker(seg, turns)


def _nearest_speaker(seg, turns: list[SpeakerTurn]) -> str:
    mid = (seg.start + seg.end) / 2
    closest = min(turns, key=lambda t: min(abs(mid - t.start), abs(mid - t.end)))
    return closest.speaker
