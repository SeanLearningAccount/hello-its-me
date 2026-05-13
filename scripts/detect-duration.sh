#!/usr/bin/env bash
# detect-duration.sh — Detect the duration of a sound file in seconds
# Usage: bash scripts/detect-duration.sh <sound file path>

set -euo pipefail

SOUND_FILE="${1:-}"

if [[ -z "$SOUND_FILE" ]]; then
  echo "Error: please provide a sound file path." >&2
  exit 1
fi

if [[ ! -f "$SOUND_FILE" ]]; then
  echo "Error: file not found: $SOUND_FILE" >&2
  exit 1
fi

# Use soxi (sox) if available, fall back to ffprobe, otherwise assume long
if command -v soxi &>/dev/null; then
  soxi -D "$SOUND_FILE"
elif command -v ffprobe &>/dev/null; then
  ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$SOUND_FILE"
else
  echo "999"
fi
