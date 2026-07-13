#!/usr/bin/env bash
# Double-click this file in Finder to pick an audio/video file and transcribe it.
# No terminal knowledge required — it opens a native file picker and, when
# done, reveals the finished transcripts in Finder.
set -euo pipefail

LAUNCHER="$HOME/.local/bin/transcrtribe"

if [[ ! -x "$LAUNCHER" ]]; then
  osascript -e 'display alert "transcrtribe is not installed" message "Run \"Install Transcrtribe.command\" first." as critical'
  exit 1
fi

FILE=$(osascript -e 'POSIX path of (choose file with prompt "Choose an audio or video file to transcribe:")' 2>/dev/null) || {
  echo "No file selected. Exiting."
  exit 0
}

OUTPUT_DIR="$HOME/Desktop/Transcrtribe Output"
mkdir -p "$OUTPUT_DIR"

echo "Transcribing: $FILE"
echo "Output folder: $OUTPUT_DIR"
echo ""

"$LAUNCHER" "$FILE" -o "$OUTPUT_DIR" -f txt,rtf,docx,pdf

echo ""
echo "Done! Opening output folder..."
open "$OUTPUT_DIR"

read -n 1 -s -r -p "Press any key to close this window..."
