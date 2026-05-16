#!/usr/bin/env bash
# its-me.sh — hello-its-me interactive menu

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOUNDS_DIR="$HOME/.claude-sounds"
SETTINGS="$HOME/.claude/settings.json"
PLAY_SCRIPT="$SCRIPT_DIR/scripts/play.sh"

# Use a function (not a string variable) so paths with spaces are passed as
# a single argument instead of being word-split.
play() {
  bash "$PLAY_SCRIPT" "$1"
}

# ── Colors ────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helper: list all wav files ─────────────────────────────────
# Caller passes the name of an array to populate (avoids piping filenames
# through a subshell, which breaks on names containing newlines).
list_sounds() {
  local out_var="$1"
  local prefix="${2:-}"
  # Guardrail: out_var is fed to `eval` below, so reject anything that isn't
  # a plain shell identifier. Today all callers pass a hardcoded literal —
  # this check is here so a future caller can't silently introduce a sink.
  if [[ ! "$out_var" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "list_sounds: invalid output variable name: $out_var" >&2
    exit 1
  fi
  shopt -s nullglob
  local matches
  if [[ -n "$prefix" ]]; then
    matches=("$SOUNDS_DIR"/"${prefix}"-*.wav "$SOUNDS_DIR"/"${prefix}"-*.mp3)
  else
    matches=("$SOUNDS_DIR"/*.wav "$SOUNDS_DIR"/*.mp3)
  fi
  shopt -u nullglob
  # Assign back to caller's named array
  eval "$out_var=(\"\${matches[@]}\")"
}

# ── 1. Test sounds ─────────────────────────────────────────────
menu_test_sounds() {
  while true; do
    echo ""
    echo -e "  ${BOLD}Test sounds${NC}"
    echo "  ─────────────────────"
    echo ""

    local files=()
    list_sounds files

    if [[ ${#files[@]} -eq 0 ]]; then
      echo "  No sound files found in $SOUNDS_DIR"
      echo ""
      return
    fi

    for i in "${!files[@]}"; do
      echo "    $((i+1)). $(basename "${files[$i]}")"
    done
    echo "    0. Back"
    echo ""

    read -rp "  Select a sound to preview: " input
    echo ""

    if [[ "$input" == "0" ]]; then
      return
    elif [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#files[@]} )); then
      play "${files[$((input-1))]}"
    else
      echo -e "  ${YELLOW}Please enter a number between 0 and ${#files[@]}.${NC}"
    fi
  done
}

# ── 2. Change sounds ───────────────────────────────────────────
change_one_sound() {
  local event_label="$1"
  local event_key="$2"
  local prefix="$3"

  while true; do
    echo ""
    echo -e "  ${BOLD}Change $event_label sound${NC}"
    echo "  ─────────────────────"
    echo ""

    local files=()
    list_sounds files

    if [[ ${#files[@]} -eq 0 ]]; then
      echo "  No $prefix sound files found in $SOUNDS_DIR"
      echo ""
      return
    fi

    for i in "${!files[@]}"; do
      echo "    $((i+1)). $(basename "${files[$i]}")"
    done
    echo "    0. Back"
    echo ""

    read -rp "  Enter number to preview, then confirm: " input
    echo ""

    if [[ "$input" == "0" ]]; then
      return
    elif [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#files[@]} )); then
      local chosen="${files[$((input-1))]}"
      play "$chosen"
      echo ""
      read -rp "  Use this sound? [y/n]: " confirm
      if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        if [[ ! -f "$SETTINGS" ]]; then
          echo -e "  ${YELLOW}⚠${NC}  Settings file not found: $SETTINGS"
          echo "     Please run install.sh first."
          echo ""
          return
        fi

        # Back up settings.json before modifying
        cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"

        SETTINGS_PATH="$SETTINGS" \
        PLAY_SCRIPT="$PLAY_SCRIPT" \
        EVENT_KEY="$event_key" \
        SOUND_PATH="$chosen" \
        python3 - <<'EOF'
import json, os, shlex, sys

settings_path = os.environ["SETTINGS_PATH"]
play_script   = os.environ["PLAY_SCRIPT"]
event_key     = os.environ["EVENT_KEY"]
sound_path    = os.environ["SOUND_PATH"]

with open(settings_path, "r") as f:
    try:
        settings = json.load(f)
    except json.JSONDecodeError as e:
        sys.exit(f"Error: {settings_path} is not valid JSON: {e}")

if not isinstance(settings, dict):
    sys.exit(f"Error: top level of {settings_path} is not a JSON object")

if not isinstance(settings.get("hooks"), dict):
    settings["hooks"] = {}

cmd = f"bash {shlex.quote(play_script)} {shlex.quote(sound_path)}"
settings["hooks"][event_key] = [{
    "matcher": "",
    "hooks": [{"type": "command", "command": cmd}],
}]

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
EOF
        echo -e "  ${GREEN}✓${NC} Updated: $event_label → $(basename "$chosen")"
        echo ""
        return
      fi
    else
      echo -e "  ${YELLOW}Please enter a number between 0 and ${#files[@]}.${NC}"
    fi
  done
}

menu_change_sounds() {
  while true; do
    echo ""
    echo -e "  ${BOLD}Change sounds${NC}"
    echo "  ─────────────────────"
    echo ""
    echo "    1. Notification sound"
    echo "    2. Permission sound"
    echo "    3. Complete sound"
    echo "    4. Error sound"
    echo "    0. Back"
    echo ""

    read -rp "  Select: " input
    echo ""

    case "$input" in
      1) change_one_sound "notification" "Notification" "notification" ;;
      2) change_one_sound "permission" "PermissionRequest" "notification" ;;
      3) change_one_sound "complete" "Stop" "complete" ;;
      4) change_one_sound "error" "StopFailure" "error" ;;
      0) return ;;
      *) echo -e "  ${YELLOW}Please enter 0–4.${NC}" ;;
    esac
  done
}

# ── 3. Add custom sound ────────────────────────────────────────
menu_add_custom_sound() {
  echo ""
  echo -e "  ${BOLD}Add custom sound${NC}"
  echo "  ─────────────────────"
  echo ""
  echo "  Place your sound file in:"
  echo -e "  ${BOLD}$SOUNDS_DIR${NC}"
  echo ""
  echo "  Supported formats: WAV, MP3"
  echo ""
  echo "  Once added, press Enter to go to Change sounds."
  echo ""
  read -rp "  Press Enter to continue..." _
  menu_change_sounds
}

# ── 9. Uninstall ───────────────────────────────────────────────
menu_uninstall() {
  echo ""
  echo -e "  ${BOLD}Uninstall${NC}"
  echo "  ─────────────────────"
  echo ""
  read -rp "  This will remove all hello-its-me settings and sound files. Continue? [y/n]: " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo ""
    echo "  Cancelled."
    echo ""
    return
  fi
  echo ""
  bash "$SCRIPT_DIR/uninstall.sh"
  exit 0
}

# ── Show current sound config ──────────────────────────────────
show_current_sounds() {
  [[ -f "$SETTINGS" ]] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  SETTINGS_PATH="$SETTINGS" python3 - 2>/dev/null <<'EOF' || true
import json, os, shlex, sys

try:
    with open(os.environ["SETTINGS_PATH"]) as f:
        settings = json.load(f)
    if not isinstance(settings, dict):
        sys.exit(0)
    hooks = settings.get("hooks", {})
    if not isinstance(hooks, dict):
        sys.exit(0)

    labels = [
        ("Notification", "Notification"),
        ("PermissionRequest", "Permission"),
        ("Stop", "Complete"),
        ("StopFailure", "Error"),
    ]

    rows = []
    for key, label in labels:
        entries = hooks.get(key)
        if not isinstance(entries, list) or not entries:
            continue
        first = entries[0]
        if not isinstance(first, dict):
            continue
        inner = first.get("hooks")
        if not isinstance(inner, list) or not inner:
            continue
        cmd = inner[0].get("command", "")
        if not cmd:
            continue
        parts = shlex.split(cmd)
        if not parts:
            continue
        filename = os.path.basename(parts[-1])
        rows.append((label, filename))

    if not rows:
        sys.exit(0)

    print("  Current sounds:")
    for label, filename in rows:
        print(f"    {label:<13}→ {filename}")
    print()
except Exception:
    pass
EOF
}

# ── Main menu ──────────────────────────────────────────────────
main_menu() {
  while true; do
    echo ""
    echo -e "  ${BOLD}hello, it's me${NC}"
    echo "  ─────────────────────"
    echo ""
    show_current_sounds
    echo "    1. Test sounds"
    echo "    2. Change sounds"
    echo "    3. How to add custom sound"
    echo "    0. Exit"
    echo ""
    echo "    u. Uninstall"
    echo ""

    read -rp "  Select: " input
    echo ""

    case "$input" in
      1) menu_test_sounds ;;
      2) menu_change_sounds ;;
      3) menu_add_custom_sound ;;
      0) echo "  Bye."; echo ""; exit 0 ;;
      u) menu_uninstall ;;
      *) echo -e "  ${YELLOW}Please enter 0–3 or u.${NC}" ;;
    esac
  done
}

afplay -v 0 /System/Library/Sounds/Tink.aiff &>/dev/null &
main_menu
