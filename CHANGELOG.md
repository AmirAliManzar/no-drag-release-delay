# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] — 2026-11-20

### Added

- The menu bar presence is a three-way mode — *Always*, *While a window is open*, *Never* —
  carried in the status menu as a submenu and in the Setup window as a segmented control.
  The window-open mode is kept in sync by the existing permission poll.
- A step-by-step permission guide in the Setup window, with buttons that open the exact
  *Accessibility* and *Trackpad* panes in System Settings.
- The contact email in the About panel.

### Changed

- The menu bar mark is the cursor glyph from the app icon, as a template image; a missing
  permission dims it instead of swapping in a different glyph.
- The status item is created and removed explicitly instead of toggled through
  `NSStatusItem.isVisible`, so it can never linger hidden in the overflow area.
- Options rows follow the macOS settings layout: label on the left, control on the right.

### Fixed

- A menu bar mode other than *Always* now guarantees the Dock icon stays on, and turning
  the Dock off falls back to *Always* — the app can no longer end up unreachable.

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

[1.1.0]: https://github.com/AmirAliManzar/no-drag-release-delay/releases/tag/v1.1.0
[1.0.0]: https://github.com/amiralimanzar/no-drag-release-delay/releases/tag/v1.0.0
