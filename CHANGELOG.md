# Changelog

## [1.1.0] - 2026-05-16

### Added
- `PermissionRequest` hook: permission dialogs ("Do you want to proceed?")
  now play the notification sound immediately, with no delay.

## [1.0.0] - 2026-05-13

### Added
- Initial release.
- `Notification`, `Stop`, and `StopFailure` hooks with sound playback via `afplay`.
- Interactive menu (`its-me`) to test, change, and manage sounds.
- Support for WAV and MP3 formats.
- Automatic double-play for sounds ≤ 3 seconds.
