# hello-its-me

**English** | [中文](./README.zh.md) | [Changelog](https://github.com/SeanLearningAccount/hello-its-me/releases)

Add audio cues to Claude Code: play a sound when a task completes, when a permission is requested, or when something errors out. Built on Claude Code's official hooks mechanism.

---

## What this is

hello-its-me responds to four Claude Code events and plays a corresponding sound for each:

| Display name | Hook name in `settings.json` | When it fires |
|---|---|---|
| **Notification** | `Notification` | Idle reminder — fires once after about 60 seconds of inactivity |
| **Permission** | `PermissionRequest` | Claude Code is asking for your confirmation — e.g. "Do you want to proceed?" |
| **Complete** | `Stop` | Claude finishes a response |
| **Error** | `StopFailure` | Claude exits abnormally |

> Note: This project uses **Complete** and **Error** as friendlier display names in the menu and docs. They map to Claude Code's official hook names `Stop` and `StopFailure` respectively. If you open `~/.claude/settings.json` directly, you'll see the latter.

Sounds play through macOS's built-in `afplay` and share the system audio output channel.

---

## Install

### Requirements

- **macOS** (other platforms not supported yet)
- **Claude Code** installed: https://github.com/anthropics/claude-code
- **zsh** (the default macOS shell). The installer registers a command in `~/.zshrc`
- **python3** (required by the installer). Usually pre-installed on macOS; if not found, run `xcode-select --install`
- **sox is recommended** (used to read audio duration — see "About sox" below):
  ```bash
    brew install sox
  ```

### Steps

1. Get the code: clone or download this repo, then `cd` into the project directory.

2. Run the installer:
   ```bash
   bash install.sh
   ```
   It will list the available sounds and let you preview and pick one for each of the three events.

3. Activate the `its-me` command:
   ```bash
   source ~/.zshrc
   ```
   Or open a new terminal window.

### What the installer does

The installer only touches the three places below. Each is backed up to `.bak.<timestamp>` before any change:

- **Creates** `~/.claude-sounds/` and copies the default sound files into it
- **Modifies** `~/.claude/settings.json` to register the four hooks. If you already have a `Notification`, `PermissionRequest`, `Stop`, or `StopFailure` hook configured, it will be overwritten (the file is backed up first).
- **Modifies** `~/.zshrc` to add an alias for the `its-me` command

> **Note:** `play.sh` stays inside the project directory. If you move or delete the project folder after installing, the hooks will silently stop working. Re-run `bash install.sh` to restore them.

Fully reversible. Uninstall cleans up all the main content. Backup files created before each change are kept — their paths are printed in the terminal when uninstall completes.

---

## Usage

### Open the menu

```bash
its-me
```

You'll see:

```
  hello, it's me
  ─────────────────────

  Current sounds:
    Notification → notification-2.wav
    Complete     → complete-3.wav
    Error        → error-1.wav

    1. Test sounds
    2. Change sounds
    3. How to add custom sound
    0. Exit

    u. Uninstall

  Select:
```

The **Current sounds** block at the top shows which sound file is currently bound to each event.

### Change sounds

Pick `2. Change sounds` → choose the event you want to change → pick a sound from the list to preview → press `y` to confirm.

Changes are written to `~/.claude/settings.json` immediately and take effect on the next event. No need to restart Claude Code.

### Add custom sounds

Drop your audio files into:

```
~/.claude-sounds/
```

Both **WAV** and **MP3** are supported. Filenames are not restricted, but a prefix convention makes things easier to manage:

- `notification-*.wav` — notifications
- `complete-*.wav` — completions
- `error-*.wav` — errors

Once dropped in, your new files appear under `2. Change sounds` and you can select them right away.

---

## How it works

### Claude Code's hooks mechanism

When certain events occur (a response completes, a permission is requested, etc.), Claude Code runs commands configured in the `hooks` field of `~/.claude/settings.json`. This is an official extension point.

hello-its-me binds all four events to the same playback script, varying only the sound file argument:

```json
{
  "hooks": {
    "Notification":     [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash /path/to/play.sh /path/to/notification.wav" }] }],
    "PermissionRequest":[{ "matcher": "", "hooks": [{ "type": "command", "command": "bash /path/to/play.sh /path/to/notification.wav" }] }],
    "Stop":             [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash /path/to/play.sh /path/to/complete.wav" }] }],
    "StopFailure":      [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash /path/to/play.sh /path/to/error.wav" }] }]
  }
}
```

### What play.sh does

When an event fires, `scripts/play.sh`:

1. Calls `scripts/detect-duration.sh` to read the audio duration (requires sox or ffmpeg — see the next section)
2. If the duration is ≤ 3 seconds: **plays the sound twice**, with a 0.3-second gap (a single play of a very short sound is easy to miss)
3. If the duration is > 3 seconds: **plays it once**
4. Playback uses macOS's built-in `afplay`, capped at 4 seconds. Sounds longer than 4 seconds will be cut off — this is intentional, to keep notifications brief.

---

## About sox

### Why it's needed

`play.sh` has to decide whether to play a sound twice, which means it needs to know how long the sound is. macOS doesn't ship with a tool that reads audio duration, so an external one is required. This project supports two:

- **`soxi`** (from the sox package) — recommended
- **`ffprobe`** (from the ffmpeg package) — alternative

Either one is enough for duration detection to work.

### What happens if neither is installed

`detect-duration.sh` falls back to a hardcoded value of `999` (treating every file as "long"), so **every sound plays once and never twice**.

If the sounds you choose are already > 3 seconds, or you don't want the play-twice behavior, you can skip this. Otherwise, sox is recommended.

### sox or ffmpeg

| | sox | ffmpeg |
|---|---|---|
| Install size | ≈ 5 MB | ≈ 80 MB and up, plus many dependencies |
| Purpose | Audio-focused; this project uses it only to read duration | General-purpose audio/video toolkit; only its duration-reading feature is used here |
| When to pick | You **don't** already have ffmpeg | You **already** have ffmpeg |

If you already have ffmpeg, you don't need sox — this project falls back to ffprobe automatically. Otherwise, sox is the lighter choice:

```bash
brew install sox
```

---

## Known issues / Troubleshooting

### Sounds get drowned out by background music

If other software is playing audio at the same time, the sound effect may be hard to hear.
Try choosing a more prominent sound, or temporarily lower the volume of your background music.

### No sound at all

Work through this checklist:

1. **System volume**: confirm you're not muted and the volume is loud enough.
2. **Test from the menu**: run `its-me` → `1. Test sounds`. If sound plays here, your audio files and the playback script are fine — the issue is in Claude Code's hooks configuration.
3. **Run the script directly**:
   ```bash
   bash scripts/play.sh ~/.claude-sounds/complete-3.wav
   ```
   If the script plays sound but Claude Code's events don't, check whether the `hooks` field in `~/.claude/settings.json` has been overwritten by another tool.
4. **Reinstall**: re-run `bash install.sh`. The installer will walk you through choosing sounds for the three events again and overwrite the existing config (the old config is backed up to `.bak.<timestamp>`).

---

## Uninstall

```bash
its-me
```

Pick `u. Uninstall`. The uninstaller removes:

- The entire `~/.claude-sounds/` directory
- The four hooks this project added to `~/.claude/settings.json` (other fields are left untouched)
- The `its-me` alias from `~/.zshrc`

As with install, everything is backed up to `.bak.<timestamp>` before removal.

### Fallback

If the `its-me` command is no longer available (for example, the alias was manually removed), `cd` into the project directory and run the uninstall script directly:

```bash
bash uninstall.sh
```

### Cleaning up backup files

After uninstalling, backup files created during install and uninstall are kept on your system. Their paths are listed in the terminal when uninstall completes. To remove them:

```bash
rm ~/.claude/settings.json.bak.* ~/.zshrc.bak.*
```

These files start with `.` and are hidden by default in Finder. To delete them via Finder, press `Cmd + Shift + G` and navigate to `~/.claude` and `~`, then press `Cmd + Shift + .` to show hidden files and delete any `.bak.*` files you find.

---

## License

MIT
