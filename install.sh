#!/usr/bin/env bash
# install.sh — hello-its-me installer

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ── Paths ─────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOUNDS_SRC="$SCRIPT_DIR/sounds/default"
SOUNDS_DST="$HOME/.claude-sounds"
SETTINGS="$HOME/.claude/settings.json"
ZSHRC="$HOME/.zshrc"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

[[ -z "$HOME" ]] && { echo "Error: \$HOME is not set." >&2; exit 1; }

echo ""
echo -e "${BOLD}  hello-its-me installer${NC}"
echo "  ─────────────────────────────"
echo ""

# ── 1. Check OS ────────────────────────────────────────────────
OS="$(uname -s)"
if [[ "$OS" != "Darwin" ]]; then
  echo -e "${RED}Error: only macOS is supported at this time.${NC}" >&2
  exit 1
fi
echo -e "  ${GREEN}✓${NC} macOS detected"

# ── 2. Check sox / ffprobe ─────────────────────────────────────
if command -v soxi &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} sox detected"
elif command -v ffprobe &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} ffprobe detected"
else
  echo -e "  ${YELLOW}⚠${NC}  sox and ffprobe not found"
  echo "     Short sounds (≤3s) will not repeat automatically."
  echo "     Recommended: brew install sox"
fi
echo ""

if ! command -v python3 &>/dev/null; then
  echo -e "${RED}Error: python3 is required but not found.${NC}" >&2
  echo "  Install via: xcode-select --install" >&2
  exit 1
fi
echo -e "  ${GREEN}✓${NC} python3 detected"

# ── 3. Copy sound files ────────────────────────────────────────
mkdir -p "$SOUNDS_DST"
shopt -s nullglob
wav_files=("$SOUNDS_SRC"/*.wav)
shopt -u nullglob
if (( ${#wav_files[@]} == 0 )); then
  echo -e "${RED}Error: no .wav files found in $SOUNDS_SRC${NC}" >&2
  exit 1
fi
cp "${wav_files[@]}" "$SOUNDS_DST/"
echo -e "  ${GREEN}✓${NC} Sound files copied to $SOUNDS_DST"
echo ""

# ── 4. Select sounds ───────────────────────────────────────────
select_sound() {
  local event_name="$1"
  local prefix="$2"
  shopt -s nullglob
  local files=("$SOUNDS_DST"/*.wav "$SOUNDS_DST"/*.mp3)
  shopt -u nullglob
  local count=${#files[@]}

  if (( count == 0 )); then
    echo -e "${RED}Error: no sound files found in $SOUNDS_DST${NC}" >&2
    exit 1
  fi

  echo "  ── Selecting sound for: ${3} ──" >&2
  echo "" >&2
  echo -e "  ${BOLD}Select $event_name sound:${NC}" >&2
  for i in "${!files[@]}"; do
    echo "    $((i+1)). $(basename "${files[$i]}")" >&2
  done
  echo "" >&2
  echo "  Enter a number to preview. Press y to confirm." >&2
  echo "" >&2

  local chosen=""
  while true; do
    read -rp "  Preview or select [1-${count}]: " input
    if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= count )); then
      afplay -t 4 "${files[$((input-1))]}"
      echo "" >&2
      read -rp "  Use this sound? [y/n]: " confirm
      if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        chosen="${files[$((input-1))]}"
        break
      fi
    else
      echo "  Please enter a number between 1 and ${count}." >&2
    fi
  done

  echo "$chosen"
}

NOTIFICATION_SOUND="$(select_sound "notification" "notification" "Notification")"
echo -e "  ${GREEN}✓${NC} Notification sound: $(basename "$NOTIFICATION_SOUND")"
echo ""

COMPLETE_SOUND="$(select_sound "complete" "complete" "Complete")"
echo -e "  ${GREEN}✓${NC} Complete sound: $(basename "$COMPLETE_SOUND")"
echo ""

ERROR_SOUND="$(select_sound "error" "error" "Error")"
echo -e "  ${GREEN}✓${NC} Error sound: $(basename "$ERROR_SOUND")"
echo ""

# ── 5. Write ~/.claude/settings.json ──────────────────────────
PLAY_SCRIPT="$SCRIPT_DIR/scripts/play.sh"

mkdir -p "$HOME/.claude"

# Back up existing settings before modifying
if [[ -f "$SETTINGS" ]]; then
  cp "$SETTINGS" "$SETTINGS.bak.$TIMESTAMP"
  echo -e "  ${GREEN}✓${NC} Backed up existing settings to $SETTINGS.bak.$TIMESTAMP"
fi

SETTINGS_PATH="$SETTINGS" \
PLAY_SCRIPT="$PLAY_SCRIPT" \
NOTIFICATION_SOUND="$NOTIFICATION_SOUND" \
COMPLETE_SOUND="$COMPLETE_SOUND" \
ERROR_SOUND="$ERROR_SOUND" \
python3 - <<'EOF'
import json, os, shlex, sys

settings_path = os.environ["SETTINGS_PATH"]
play_script   = os.environ["PLAY_SCRIPT"]
sounds = {
    "Notification": os.environ["NOTIFICATION_SOUND"],
    "Stop":         os.environ["COMPLETE_SOUND"],
    "StopFailure":  os.environ["ERROR_SOUND"],
    "PermissionRequest": os.environ["NOTIFICATION_SOUND"],
}

def make_hook(sound_path):
    cmd = f"bash {shlex.quote(play_script)} {shlex.quote(sound_path)}"
    return [{
        "matcher": "",
        "hooks": [{"type": "command", "command": cmd}],
    }]

if os.path.exists(settings_path):
    with open(settings_path, "r") as f:
        try:
            settings = json.load(f)
        except json.JSONDecodeError as e:
            sys.exit(f"Error: {settings_path} is not valid JSON: {e}")
    if not isinstance(settings, dict):
        sys.exit(f"Error: top level of {settings_path} is not a JSON object")
else:
    settings = {}

if not isinstance(settings.get("hooks"), dict):
    settings["hooks"] = {}

for event, sound in sounds.items():
    settings["hooks"][event] = make_hook(sound)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
EOF

echo -e "  ${GREEN}✓${NC} Written to $SETTINGS"
echo ""

# ── 6. Register its-me command ─────────────────────────────────
# printf %q escapes special characters so the path round-trips safely
# through the shell when the alias is expanded.
QUOTED_TARGET="$(printf '%q' "$SCRIPT_DIR/its-me.sh")"
ALIAS_LINE="alias its-me=\"bash $QUOTED_TARGET\""

# Back up .zshrc before modifying
if [[ -f "$ZSHRC" ]]; then
  cp "$ZSHRC" "$ZSHRC.bak.$TIMESTAMP"
fi

if grep -q '^alias its-me=' "$ZSHRC" 2>/dev/null; then
  tmp="$(mktemp)"
  grep -v '^alias its-me=' "$ZSHRC" > "$tmp" || true
  # Overwrite in place so the original file's mode/owner/inode are preserved
  cat "$tmp" > "$ZSHRC"
  rm -f "$tmp"
  printf '%s\n' "$ALIAS_LINE" >> "$ZSHRC"
  echo -e "  ${GREEN}✓${NC} its-me command updated"
else
  printf '\n# hello-its-me\n%s\n' "$ALIAS_LINE" >> "$ZSHRC"
  echo -e "  ${GREEN}✓${NC} its-me command registered"
fi

echo ""
echo -e "  ${BOLD}Installation complete!${NC}"
echo ""
echo "  Run the following to activate its-me immediately:"
echo -e "  ${BOLD}source ~/.zshrc${NC}"
echo ""
