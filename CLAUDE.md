# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Maclippy is a macOS **menu-bar-only** clipboard manager (SwiftUI + SwiftData, macOS 14+, zero third-party dependencies). It polls the system pasteboard, stores recent text clips, and re-copies a chosen clip on click. `LSUIElement = 1` — no Dock icon, no main window.

**`docs/SPEC.md` is the design source of truth.** It documents the KISS philosophy and every deliberately-hardcoded value (poll interval, 2 MB max clip, etc.). Read it before adding behavior or turning a constant into a preference — many "missing" knobs are intentional, and §9 lists what's explicitly out of scope. Per-feature specs live alongside it in `docs/`.

## Commands

Day-to-day development is Xcode (⌘R). The `Makefile` wraps the CLI equivalents CI uses:

- `make build` — Debug build, ad-hoc signed (`xcodebuild ... -derivedDataPath build`)
- `make run` — build, then launch (look for the icon in the menu bar)
- `make lint` — `swiftlint lint --strict` (requires `brew install swiftlint`)
- `make install` — Release build → replace `~/Applications/Maclippy.app` → relaunch
- `make clean` — remove `build/`

There is **no test target** and no tests yet — `make test` does not exist. Ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`) means a fresh clone builds with no Apple ID, certificate, or team.

## Architecture

Two SwiftUI scenes in `MaclippyApp.swift`, both attached to one shared `ModelContainer`: a `MenuBarExtra` (`.menu` style) hosting `ClipMenu`, and a `Settings` scene hosting `SettingsView` (General + Clips tabs). A single `ClipboardMonitor` is created at launch with the container's `mainContext` and injected into both.

The one `@Model` is `Clip` (plain + optional rtf/html + `pinned`/`pinnedOrder`/`dateRecorded`/`displayTitle`). Payloads are stored inline; text-only in v1.

### The central quirk: the menu does NOT use `@Query`

`@Query` inside a `MenuBarExtra` does not come alive until some other window touches the SwiftData stack, so the menu would render empty on launch. The fix, which spans `ClipboardMonitor` and `ClipMenu`:

- `ClipboardMonitor` is `@Observable` and publishes `pinned` / `recent` snapshot arrays. `ClipMenu` reads **those**, never `@Query`.
- The monitor calls `reload()` (refetch both arrays) on init and from an observer on `ModelContext.didSave`, so any save from anywhere — capture, or pin/delete/reorder in Settings — refreshes the menu.
- **Batch deletes bypass this.** `context.delete(model:where:)` writes straight to the store and emits no `didSave`, so `clearHistory()` must call `reload()` explicitly. Keep this in mind for any new bulk mutation.

The Settings views (`ClipsSettingsView`) *do* use `@Query` + `@Environment(\.modelContext)` — that's fine, they run in a real window. If you change a `@Query`'s filter/sort there, mirror it in `ClipboardMonitor.reload()` so the menu and Settings agree.

### Capture pipeline (`ClipboardMonitor`)

macOS has no clipboard-change notification, so a 0.3s `Timer` polls `NSPasteboard.general.changeCount`. On change, `capture()`:
- skips concealed items (when the preference is on) and all-whitespace content;
- treats history as **unique by verbatim `plain`** — re-copying existing content bumps its `dateRecorded` instead of inserting a duplicate;
- degrades over 2 MB (drop rich reps → keep plain → skip entirely) rather than truncating.

`paste()` writes every stored representation back, sets `lastChangeCount` to suppress self-capture, and bumps `dateRecorded` so a reused clip moves to the top.

### Preferences

User-facing settings persist via `@AppStorage` (UserDefaults), registered in `Preferences.swift`. History size is a 0–99 stepper where **0 means unlimited** (`trim()` no-ops); lowering it calls `monitor.enforceHistoryLimit()` to trim immediately. Everything in `docs/SPEC.md` §7 "Not exposed" is hardcoded on purpose.

## Conventions

- **Menu labels** are built from `clip.plain` via `ClipMenu`, truncated to `maxItemLength` (36); tabs/newlines render as glyphs and leading/trailing spaces as `·` so verbatim-distinct clips (e.g. `"foo"` vs `" foo "`) don't look identical.
- **Comments**: explain non-obvious *why* only; no narration comments.

## Git workflow

- Default branch is **`develop`**; `main` is the release line. Both are public and kept to clean, meaningful history.
- **`wip`** is the scratch branch for loose/experimental commits. Land finished work on `develop` as one clean commit (`git merge --squash wip`), never by pushing `wip`'s history onto `main`/`develop`.
- **Do not add a `Co-Authored-By` trailer** to commits in this repo.
