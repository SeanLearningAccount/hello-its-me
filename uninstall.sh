#!/usr/bin/env bash
# uninstall.sh — Remove hello-its-me completely

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

SOUNDS_DST="$HOME/.claude-sounds"
SETTINGS="$HOME/.claude/settings.json"
ZSHRC="$HOME/.zshrc"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

[[ -z "$HOME" ]] && { echo "Error: \$HOME is not set." >&2; exit 1; }

echo ""
echo -e "${BOLD}  hello-its-me uninstaller${NC}"
echo "  ─────────────────────────────"
echo ""

read -rp "  This will remove all hello-its-me settings and sound files. Continue? [y/n]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo ""
  echo "  Cancelled."
  echo ""
  exit 0
fi
echo ""

# ── 1. Remove hooks from settings.json ────────────────────────
if [[ -f "$SETTINGS" ]]; then
  cp "$SETTINGS" "$SETTINGS.bak.$TIMESTAMP"

  SETTINGS_PATH="$SETTINGS" python3 - <<'EOF'
import json, os, sys

settings_path = os.environ["SETTINGS_PATH"]

with open(settings_path, "r") as f:
    try:
        settings = json.load(f)
    except json.JSONDecodeError as e:
        sys.exit(f"Error: {settings_path} is not valid JSON: {e}")

if not isinstance(settings, dict):
    sys.exit(f"Error: top level of {settings_path} is not a JSON object")

hooks = settings.get("hooks", {})
if not isinstance(hooks, dict):
    hooks = {}

for key in ["Notification", "Stop", "StopFailure", "PermissionRequest"]:
    hooks.pop(key, None)

if not hooks:
    settings.pop("hooks", None)
else:
    settings["hooks"] = hooks

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
EOF
  echo -e "  ${GREEN}✓${NC} Hooks removed from $SETTINGS (backup: $SETTINGS.bak.$TIMESTAMP)"
else
  echo -e "  ${YELLOW}⚠${NC}  $SETTINGS not found, skipping."
fi

# ── 2. Remove sound files ──────────────────────────────────────
if [[ -d "$SOUNDS_DST" ]]; then
  rm -rf "$SOUNDS_DST"
  echo -e "  ${GREEN}✓${NC} Removed $SOUNDS_DST"
else
  echo -e "  ${YELLOW}⚠${NC}  $SOUNDS_DST not found, skipping."
fi

# ── 3. Remove alias from .zshrc ───────────────────────────────
# Match only lines that start with our exact markers, so we never touch
# unrelated content that happens to contain the substring.
if [[ -f "$ZSHRC" ]] && grep -qE '^(# hello-its-me$|alias its-me=)' "$ZSHRC"; then
  cp "$ZSHRC" "$ZSHRC.bak.$TIMESTAMP"
  tmp="$(mktemp)"
  grep -vE '^(# hello-its-me$|alias its-me=)' "$ZSHRC" > "$tmp" || true
  # Overwrite in place so the original file's mode/owner/inode are preserved
  cat "$tmp" > "$ZSHRC"
  rm -f "$tmp"
  echo -e "  ${GREEN}✓${NC} its-me alias removed from $ZSHRC (backup: $ZSHRC.bak.$TIMESTAMP)"
else
  echo -e "  ${YELLOW}⚠${NC}  its-me alias not found in $ZSHRC, skipping."
fi

echo ""
echo -e "  ${BOLD}Done.${NC} hello-its-me has been removed."
echo ""
echo "  Run the following to apply changes immediately:"
echo -e "  ${BOLD}source ~/.zshrc${NC}"
echo ""
found=0
for f in ~/.claude/settings.json.bak.* ~/.zshrc.bak.*; do
  [ -e "$f" ] && found=1 && break
done

if [ "$found" -eq 1 ]; then
  echo ""
  echo "Backup files have been kept (delete manually if no longer needed):"
  for f in ~/.claude/settings.json.bak.* ~/.zshrc.bak.*; do
    [ -e "$f" ] && echo "  $f"
  done
  echo ""
  echo "To delete them all at once:"
  echo "  rm ~/.claude/settings.json.bak.* ~/.zshrc.bak.*"
fi
