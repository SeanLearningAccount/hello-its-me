#!/usr/bin/env bash
# play.sh — Play a sound file
# Usage: bash scripts/play.sh <sound file path>

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

OS="$(uname -s)"

play_sound() {
  case "$OS" in
    Darwin)
      afplay -t 4 "$SOUND_FILE"
      ;;
    *)
      echo "Error: only macOS is supported at this time." >&2
      exit 1
      ;;
  esac
}

DURATION="$(bash "$(dirname "$0")/detect-duration.sh" "$SOUND_FILE")"

if [[ "$DURATION" =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$DURATION <= 3" | bc -l) )); then
  play_sound
  sleep 0.3
  play_sound
else
  play_sound
fi
