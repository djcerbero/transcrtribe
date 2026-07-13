"""Group Whisper segments into speaker turns for conversation-style output."""
from __future__ import annotations

from dataclasses import dataclass

from .transcriber import Segment


@dataclass
class ConversationTurn:
    speaker: str
    start: float
    end: float
    text: str


def build_conversation(segments: list[Segment]) -> list[ConversationTurn]:
    turns: list[ConversationTurn] = []
    for seg in segments:
        speaker = seg.speaker or "Speaker 1"
        if turns and turns[-1].speaker == speaker:
            turns[-1].text = f"{turns[-1].text} {seg.text}".strip()
            turns[-1].end = seg.end
        else:
            turns.append(ConversationTurn(speaker=speaker, start=seg.start, end=seg.end, text=seg.text))
    return turns


def format_timestamp(seconds: float) -> str:
    seconds = max(0, int(seconds))
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    if h:
        return f"{h:02d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"
