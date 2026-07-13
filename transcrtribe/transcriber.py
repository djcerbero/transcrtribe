"""Speech-to-text transcription backed by faster-whisper."""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Word:
    start: float
    end: float
    text: str


@dataclass
class Segment:
    start: float
    end: float
    text: str
    words: list[Word] = field(default_factory=list)
    speaker: str | None = None


def transcribe(
    audio_path: str,
    model_size: str = "small",
    language: str | None = None,
    device: str = "auto",
    compute_type: str = "default",
) -> tuple[list[Segment], str]:
    """Run Whisper transcription and return (segments, detected_language)."""
    from faster_whisper import WhisperModel

    if device == "auto":
        device = _pick_device()

    model = WhisperModel(model_size, device=device, compute_type=compute_type)

    raw_segments, info = model.transcribe(
        audio_path,
        language=language,
        word_timestamps=True,
        vad_filter=True,
    )

    segments: list[Segment] = []
    for seg in raw_segments:
        words = [Word(w.start, w.end, w.word.strip()) for w in (seg.words or [])]
        segments.append(Segment(start=seg.start, end=seg.end, text=seg.text.strip(), words=words))

    return segments, info.language


def _pick_device() -> str:
    try:
        import torch

        if torch.cuda.is_available():
            return "cuda"
    except Exception:
        pass
    return "cpu"
