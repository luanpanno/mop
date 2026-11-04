# Changelog

All notable changes to Mop are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org).

## [Unreleased]

## [0.2.0] - 2026-11-03

### Added
- App icon.
- Contributing guide, security policy, issue and pull request templates, Dependabot.
- Settings now live in the main window's sidebar (at the bottom, above the disk bar), with a redesigned layout.
- Sidebar toggle button in the toolbar.

### Fixed
- The window layout no longer jumps when switching between screens.
- The Mop window now comes to the front with focus when you launch Mop, or open it again while it runs in the menu bar.

## [0.1.0] - 2026-11-03

### Added
- Uninstaller that finds and removes app leftovers (Application Support, caches, preferences,
  containers, launch agents and more).
- Cleanup of app caches, logs, browser caches, package manager caches, Xcode data, simulator caches and the Trash.
- Disk overview with used, available and purgeable space, junk by category, and space by folder.
- Large & old files finder and duplicate files finder.
- Menu bar item: a left click opens the popover, a right click opens a menu.
- Low-disk notifications, scheduled auto-clean, detection of apps deleted outside Mop,
  Full Disk Access onboarding, and launch at login.

[Unreleased]: https://github.com/luanpanno/mop/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/luanpanno/mop/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/luanpanno/mop/releases/tag/v0.1.0
