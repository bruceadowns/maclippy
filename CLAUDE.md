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
- `make inc-ver` — bump the build number (`agvtool next-version`, no `-all` — the project has no `Info.plist` to write, it's generated)

There is **no test target** and no tests yet — `make test` does not exist. Ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`) means a fresh clone builds with no Apple ID, certificate, or team.

## Architecture

Two SwiftUI scenes in `MaclippyApp.swift`, both attached to one shared `ModelContainer`: a `MenuBarExtra` (`.menu` style) hosting `ClipMenu`, and a `Settings` scene hosting `SettingsView` (General + Clips tabs). A single `ClipboardMonitor` is created at launch with the container's `mainContext` and injected into both.

The one `@Model` is `Clip` (plain + optional rtf/html + `pinned`/`pinnedOrder`/`dateRecorded`/`displayTitle` + optional `customLabel`). Payloads are stored inline; text-only in v1. The container is given an explicit `ModelConfiguration` URL so the store is namespaced at `~/Library/Application Support/Maclippy/Maclippy.store` rather than SwiftData's bare `default.store`. `customLabel` is a user-set name that cloaks a **pinned** clip's content in the UI (e.g. a password), set/cleared only via the Clips tab; see `docs/name-pinned-clip.md`. **Cloaking is visual only — the payload is plaintext at rest** (SPEC §6); encrypting it is a tracked roadmap item.

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

- **Labels** for unnamed clips come from `Clip.revealedPlain` — tabs/newlines render as glyphs and leading/trailing spaces as `·` so verbatim-distinct clips (e.g. `"foo"` vs `" foo "`) don't look identical. Shared by the menu (`ClipMenu`, further truncated to `maxItemLength` 36) and the Clips tab, so they label identically. `displayTitle` is now only the clean seed for the rename field, not a row label. A pinned clip with a `customLabel` instead shows that name (no whitespace-reveal) with a `key.fill` glyph, in both the menu and the Clips tab.
- **Comments**: explain non-obvious *why* only; no narration comments.
- **Every text file ends with a newline.** SwiftLint's `trailing_newline` rule covers Swift; docs, fixtures, and the Makefile are not linted, so it's on you. `Reformat` holds itself to the same rule — its output always terminates with exactly one line feed (`docs/reformat.md` §4).

## Git workflow

- Default branch is **`develop`**; `main` is the release line. Both are public and kept to clean, meaningful history.
- **`wip`N** (`wip1`, `wip2`, …) are scratch branches for loose/experimental commits. Push them freely — the constraint is on what lands, not on what's pushed.
- **Work happens on the wip branch; don't create a topic branch for it.** The wip branch *is* the PR branch. Creating a second branch to hold the work adds a step, and pre-squashing onto one produces the right diff by the wrong route.
- **Finished work reaches `develop` as exactly one commit.** Open a PR from the wip branch against `develop` and **squash-merge** it. The wip branch keeps its messy history for review; `develop` gets one clean commit. Wip's individual commits must never land on `develop` or `main`.
- **Do not add a `Co-Authored-By` trailer** to commits in this repo.
