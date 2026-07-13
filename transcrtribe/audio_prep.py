"""Loudness normalization preprocessing via ffmpeg's EBU R128 loudnorm filter."""
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path


class NormalizationUnavailable(Exception):
    pass


def normalize_audio(audio_path: str) -> Path:
    """Loudness-normalize audio_path via ffmpeg; return the path to a new temp WAV.

    Raises NormalizationUnavailable if ffmpeg is missing or fails, so callers
    can fall back to the original file. On any raised failure, this function
    has already cleaned up anything it created — callers only need to clean
    up the path on a successful return.
    """
    if shutil.which("ffmpeg") is None:
        raise NormalizationUnavailable("ffmpeg not found on PATH; skipping loudness normalization.")

    fd, tmp_name = tempfile.mkstemp(suffix=".wav", prefix="transcrtribe-norm-")
    os.close(fd)
    output_path = Path(tmp_name)

    cmd = [
        "ffmpeg", "-y", "-nostdin",
        "-i", audio_path,
        "-af", "loudnorm=I=-16:TP=-1.5:LRA=11",
        "-ac", "1", "-ar", "16000",
        "-c:a", "pcm_s16le",
        str(output_path),
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
    except OSError as exc:
        output_path.unlink(missing_ok=True)
        raise NormalizationUnavailable(f"Could not run ffmpeg: {exc}") from exc

    if result.returncode != 0:
        output_path.unlink(missing_ok=True)
        stderr_tail = "\n".join(result.stderr.strip().splitlines()[-5:])
        raise NormalizationUnavailable(f"ffmpeg loudness normalization failed: {stderr_tail}")

    return output_path
