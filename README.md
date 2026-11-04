<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="Mop icon">
</p>

<h1 align="center">Mop</h1>

<p align="center">
  <a href="https://github.com/luanpanno/mop/actions/workflows/ci.yml"><img src="https://github.com/luanpanno/mop/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/luanpanno/mop/releases/latest"><img src="https://img.shields.io/github/v/release/luanpanno/mop" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-blue" alt="macOS 26+">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/luanpanno/mop" alt="MIT license"></a>
</p>

**Mop** is a free, open-source macOS app that keeps your disk clean:

- **Uninstaller**: removes apps *and* the files they leave behind (Application Support, caches, preferences, containers, launch agents…).
- **Cleanup**: clears user caches, logs, browser caches, Xcode DerivedData, package manager caches and more.
- **Disk overview**: total, used, available and purgeable space, and how much Mop can free.
- **Large & old files** and **duplicate files** finders.
- **Menu bar item**: a left click opens a quick disk panel, a right click opens a menu (Open Mop, Settings, Quit…).
- Extras: low-disk notifications, scheduled auto-clean of safe categories, detection of apps deleted outside Mop, and Full Disk Access onboarding.

Mop never deletes files permanently: everything is **moved to the Trash**, so you can put it back. The only exception is the explicit *Empty Trash* action.

## How Mop keeps your files safe

- **Nothing is deleted permanently.** Every removal moves items to the Trash, so you can use *Put Back*.
  The only exception is the *Empty Trash* category, which asks for confirmation first.
- **You review before anything is removed.** Each screen shows what will be removed and its size, with checkboxes.
- **Leftovers are matched conservatively.** Only files named after the app's bundle identifier
  (for example `com.foo.app.plist`) are preselected. Files that only share the app's name are marked
  *Possible match* and stay unchecked.
- **Protected locations are off-limits.** A safety check blocks system folders (`/System`, `/usr`, …), Apple apps,
  top-level folders such as `~/Library/Caches` itself, and Mop itself, whatever the UI asks for.
- **Apple's own caches are skipped**, and auto-clean only touches categories marked safe, which are files that apps rebuild.
- **Everything is logged** in `~/Library/Application Support/Mop/removals.log`.

## Install

Download the latest `Mop-x.y.z.zip` from [Releases](https://github.com/luanpanno/mop/releases), unzip it and move `Mop.app` to `/Applications`.
Builds aren't notarized yet, so the first time you open it, run `xattr -dr com.apple.quarantine /Applications/Mop.app` (or use *Open Anyway* in System Settings → Privacy & Security).

To cut a release, bump `CFBundleShortVersionString` in `Resources/Info.plist`, then push a matching tag (`git tag v0.2.0 && git push origin v0.2.0`). The Release workflow builds, zips and publishes it.

## Requirements

- macOS 26 or later
- Swift 6 toolchain (Command Line Tools is enough; Xcode is optional)

## Build & run

```bash
scripts/build-app.sh          # builds build/Mop.app (ad-hoc signed)
open build/Mop.app
```

Run the tests:

```bash
swift test
```

With Xcode installed, you can also generate an Xcode project:

```bash
brew install xcodegen
xcodegen generate
open Mop.xcodeproj
```

### Notes for building without Xcode

- Recent SDKs declare SwiftUI's `@State` as a macro whose compiler plugin ships only with Xcode.
  Views therefore use `@ViewState`, a type alias for the `State` property wrapper that builds with
  both the Command Line Tools and Xcode.
- If `swift test` reports `plugin for module 'TestingMacros' not found`, run it again. The
  Command Line Tools sometimes fail to load the plugin on a fresh build.
- Notifications and launch at login only work from the `.app` bundle, not from `swift run`.

## Full Disk Access

Some folders (Mail, Safari, other apps' containers) can only be scanned with **Full Disk Access**.
Mop explains this on first launch and links to *System Settings → Privacy & Security → Full Disk Access*.
After a rebuild, the ad-hoc signature changes, so you may need to toggle the permission again.

## Project layout

```
Sources/MopCore   scanning, leftover matching, cleanup rules, safety checks, Trash removal (no UI)
Sources/Mop       AppKit lifecycle, menu bar item, SwiftUI views, background monitors
Tests/            unit tests for MopCore (Swift Testing)
```

## Roadmap

- Developer ID signing, notarization, DMG releases, Homebrew cask
- Sparkle auto-updates
- Portuguese (pt-BR) translation

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Report safety issues privately as described in [SECURITY.md](SECURITY.md).
Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE).
