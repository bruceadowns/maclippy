# Feature spec — About Maclippy

**Status:** approved, not yet implemented. Per-feature spec; extends
[`SPEC.md`](SPEC.md), where section references (§) point unless noted.

## 1. Summary

Add an **About Maclippy** item to the menu that opens the **system standard
About panel** — app icon, name, version, copyright/license, and a short credit
line with a clickable link to the project repo. No custom window.

## 2. Rationale / KISS fit

- The app is `LSUIElement` (no Dock, no app menu), so there's no default
  "About" anywhere — a source-distributed app still wants a visible version and
  a way back to the repo.
- Uses AppKit's built-in panel (`orderFrontStandardAboutPanel`) — zero
  dependencies, no new `Scene`, no SwiftUI window, no state. Fully on-brand with
  "system frameworks only" (§3).
- Content is minimal and auto-populated from `Info.plist`; the only custom bit
  is a one-line credit + link.

## 3. Menu placement (§5 change)

`About Maclippy` sits in the actions cluster, directly above `Preferences…`,
mirroring the standard macOS app-menu order (About → Settings → … → Quit).
`Quit` stays last. No new divider — the cluster stays one compact group, in
keeping with §5's sparse-divider rule.

```
─────────────────────────   ← existing clips │ app divider
About Maclippy               ← new
Preferences…
Quit Maclippy
```

- **No ellipsis.** Apple convention is "About <App>" / "About This Mac" with no
  `…`, even though it opens a window — the `…` is reserved for commands needing
  further input. This is a deliberate exception to §5's "dialog-openers get `…`"
  rule; note it there.

## 4. The panel

Invoked with:

```swift
Button("About Maclippy") {
    NSApp.activate(ignoringOtherApps: true)  // LSUIElement: bring the panel forward
    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
}
```

- `NSApp.activate(...)` first — same pattern as `Preferences…` in `ClipMenu`;
  without it the panel can open behind other apps for a menu-bar agent.
- **Icon / name / version / build** — automatic from the app bundle
  (`CFBundleShortVersionString`, `CFBundleVersion`) and the app icon. No code.
- **Copyright / license** — from `NSHumanReadableCopyright`:
  `© 2026 Bruce Downs · MIT`. **Name only, no email.**
- **Credits** (the one custom value) — an `NSAttributedString` passed as
  `.credits`: a one-line description plus a **clickable** repo link, e.g.

  > A menu-bar clipboard manager.
  > https://github.com/bruceadowns/maclippy

  The URL carries an `.link` attribute so the panel renders it as a live
  hyperlink (opens in the default browser). No email address anywhere.

## 5. Prerequisites

The bundle uses `GENERATE_INFOPLIST_FILE = YES`, so these are Xcode **build
settings**, not a checked-in `Info.plist`:

- `MARKETING_VERSION` (→ `CFBundleShortVersionString`) — already `0.1.0`.
- `CURRENT_PROJECT_VERSION` (→ `CFBundleVersion`) — already `1`.
- `INFOPLIST_KEY_NSHumanReadableCopyright` — changed from
  "…All rights reserved." to `© 2026 Bruce Downs · MIT` (the old value
  contradicted the MIT `LICENSE`).

## 6. Implementation touchpoints

- `Support/ClipActions.swift` — `showAbout()` (opens the panel) + `aboutCredits()`
  (the attributed credit line + link); reuses the existing `appIcon()` since
  agent apps don't reliably load the bundle icon at runtime.
- `Views/ClipMenu.swift` — `About Maclippy` button above `Preferences…`, no new
  divider.
- `Maclippy.xcodeproj` — `INFOPLIST_KEY_NSHumanReadableCopyright` per §5.
- No model, persistence, or `ClipboardMonitor` changes. No new assets. No tests
  (no test target).

Docs to fold in once built:

- `docs/SPEC.md` — §5 menu structure (new item + ellipsis exception),
  and the §8 scaffolding note that About uses the standard panel.

## 7. Out of scope

- A custom SwiftUI About window / bespoke layout.
- Acknowledgements / third-party licenses (there are no dependencies).
- Email or other contact details in the binary — the repo (Issues) is the
  contact channel; put anything more in the README.
- "Check for updates" — belongs with a future signed/notarized release + Sparkle
  (SPEC §9), not here.
