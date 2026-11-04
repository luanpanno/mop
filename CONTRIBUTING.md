# Contributing to Mop

Thanks for helping! Bug reports, ideas and pull requests are all welcome.

## Getting started

```bash
git clone git@github.com:luanpanno/mop.git
cd mop
swift test                    # run the unit tests
scripts/build-app.sh debug    # build build/Mop.app
open build/Mop.app
```

Command Line Tools are enough. With Xcode installed you can also run `xcodegen generate` and open `Mop.xcodeproj`.

## Project layout

| Path | What lives there |
| --- | --- |
| `Sources/MopCore` | Scanning, leftover matching, cleanup rules, `SafetyGuard`, Trash removal. No UI, fully unit-tested. |
| `Sources/Mop` | AppKit lifecycle, menu bar item, SwiftUI views, background monitors. |
| `Tests/MopCoreTests` | Swift Testing tests. Use `TempDir` fixtures and never touch real user files. |
| `scripts/` | App bundling and icon generation. |

## Ground rules

- **Safety first.** Every removal must go through `TrashService`, which checks `SafetyGuard`. Never call
  `FileManager.removeItem` on user files directly. The only permanent deletion is the explicit *Empty Trash* action.
- **Be conservative when matching leftovers.** Only bundle-identifier matches may be preselected. Name-only
  matches must stay unchecked (`Leftover.Confidence.possible`).
- **Add tests** for new cleanup categories, matching rules or safety rules.
- **Use `@ViewState` instead of `@State`** in views. Recent SDKs declare `@State` as a macro that only builds
  with Xcode; `ViewState` is a type alias for the property wrapper and builds everywhere.
- Keep Swift 6 strict concurrency clean: `swift build` should produce no warnings.

## Adding a cleanup category

1. Add a `CleanupCategory` to `CleanupCatalog.all()` in `Sources/MopCore/CleanupCategory.swift`.
2. Set `isSafeForAutoClean` only if the files are regenerated automatically and removing them never loses user data.
3. If its folders live inside `~/Library/Caches`, add them to the `userCaches` exclusions so nothing is counted twice.
4. Add a test.

## Pull requests

- Keep each PR focused on one change, and describe what you tested.
- CI must pass (SwiftPM build and tests, plus the Xcode project build).
- Add a line to the `Unreleased` section of `CHANGELOG.md` for user-facing changes.

## Releasing (maintainers)

1. Move the `Unreleased` notes in `CHANGELOG.md` under a new version heading.
2. Bump `CFBundleShortVersionString` (and `CFBundleVersion`) in `Resources/Info.plist`.
3. Commit, then `git tag vX.Y.Z && git push origin main vX.Y.Z`. The Release workflow publishes it.
