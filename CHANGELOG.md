# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-11-20

### Added

- Menu bar app that releases a tap-drag as soon as the last trackpad contact ends.
- Event-tap based duplicate suppression, so the system's own delayed `leftMouseUp` cannot
  turn into a stray click.
- First-run window with permission status, trackpad configuration checks, and a drag test.
- Independent "Show in Menu Bar" and "Show in Dock" switches, with a guard that keeps the
  app reachable through at least one of them.
- Launch at login via `SMAppService`.
- Universal build (`arm64` + `x86_64`), per-architecture `.pkg` installers, and a universal
  `.dmg`.
- Rotating diagnostic log at `~/Library/Logs/NoDragReleaseDelay.log`.

### Notes

- Requires macOS 13 or later and Accessibility permission.
- Inactive while drag lock is enabled, by design.

[1.0.0]: https://github.com/amiralimanzar/no-drag-release-delay/releases/tag/v1.0.0
