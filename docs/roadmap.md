# Maclippy — Roadmap

Forward-looking companion to [`SPEC.md`](SPEC.md). §9 of the spec lists what's out
of scope for v1; this doc takes a position on it — ordered by conviction, not just
enumerated. Everything here stays subject to the KISS lens in SPEC §1: complexity
must earn its place, and "defer, don't pre-build" is the default.

## Recommended sequence

1. **⌘1–⌘9 quick-paste** for the top pinned/recent clips. Plain
   `NSMenuItem.keyEquivalent` — no new window, no Accessibility permission. Cheap,
   high payoff; the one item worth pulling forward first.
2. **Search + picker panel.** A search field over history — which means a floating
   `NSPanel` picker, since `NSMenu` can't host a live text field. This is the
   identity-defining change: it pulls in a **global hotkey** to summon the panel,
   which pulls in a **shortcut-recorder** UI — three deferred items arriving
   together. Worth it, but it's the point Maclippy stops being "a menu" and becomes
   "an app with a menu." Design before code.
3. **Image (and file) capture.** The biggest "oh, it doesn't do that" gap. Model
   adds a `type` + **external blob storage**; brings thumbnails and store-size
   management, and retires the 2 MB text rule (SPEC §4.3) as-is. Sequenced after
   search because search is what makes a larger history usable.
4. **A distributable binary.** Not a feature but the real ceiling on audience:
   source-only limits Maclippy to developers. Getting a signed, downloadable
   release unlocks non-developer users — arguably higher leverage than any single
   feature. Options and the recommended path are in
   [Distribution options](#distribution-options) below.

## Hardening & engineering health

Not user-facing features — the two gaps most worth closing before the codebase
grows. Neither is in SPEC §9; both are called out here so they aren't forgotten.

- **Encrypt cloaked payloads at rest.** The named-clip feature (SPEC §6,
  [`name-pinned-clip.md`](name-pinned-clip.md)) invites users to stash a password
  behind a label, but the cloak is *visual only* — the SwiftData store is
  plaintext on disk. v1 documents this as an accepted trade-off (SPEC §6 note),
  which is honest but thin the moment a non-developer trusts it with a real
  secret. The fix that keeps KISS: store the payload of a `customLabel`'d clip in
  the **Keychain**, keyed by the clip's `id`, and keep only the reference in
  SwiftData — no crypto code, no new dependency, and scoped to just the clips a
  user deliberately cloaked. Do this before promoting the cloak feature to any
  non-developer audience (i.e. alongside the distribution work below).
- **A minimal test target.** There is none today (see `CLAUDE.md`). The capture
  pipeline holds the fiddly invariants most likely to regress silently in a
  refactor — de-dupe by verbatim `plain`, the 2 MB degrade-don't-truncate ladder
  (SPEC §4.3), trim-with-pinned-exempt (SPEC §4.4). A small XCTest target over
  that pure-ish logic is insurance, not ceremony. Best sequenced **just before**
  the search + picker work (#2 above), which is the change most likely to disturb
  the pipeline.

## Tempting — defer hard or skip

- **Auto-paste into the active app.** Costs an Accessibility permission and
  focus-restore machinery, breaking the "fresh clone Just Works, no permissions"
  promise. Real value, KISS-refusing tax — revisit only once search exists and
  users ask.
- **Rich-text paste-format control** (global preference or ⌥-to-paste-plain
  gesture). Clear Formatting (SPEC §4.8) already covers the common case.
- **Per-app exclusion list.** Pause (SPEC §4.5) + concealed-item detection
  (SPEC §4.6) already cover the password case, which is most of the demand.
- **Source-app tracking** (which app a clip came from) and **usage/frequency
  ranking** (`totalPastes`-style). Self-surveillance for marginal payoff; ranking
  also fights recency, which is the right default.
- **Trim leading/trailing whitespace on capture** (a preference; default off —
  clips are stored and matched verbatim today).

## Distribution options

Today: **source-only** — clone, build in Xcode, ad-hoc signed (SPEC §2). Zero
setup, zero cost, developer audience only. Everything below is what it takes to
reach past that audience, cheapest-first.

- **Direct download — Developer ID + notarization (recommended path).** A
  Developer ID–signed, notarized `.app` (`.dmg`/`.zip`) on **GitHub Releases**,
  built by CI. Costs the **$99/yr Apple Developer Program** and a notarization step
  in the build. This is the unlock: it clears Gatekeeper on any Mac and is the
  prerequisite for **Sparkle auto-update** (which is meaningless without a hosted
  binary to update to). Do this one first; the rest ride on it.
- **Homebrew Cask.** Once a notarized release exists, a `maclippy` cask is nearly
  free and fits the current audience's muscle memory (`brew install --cask
  maclippy`). Auto-updates via `brew upgrade` — an alternative to Sparkle, not an
  addition. Low effort, high fit; natural second step.
- **Mac App Store.** Widest reach and handles signing/updates for you, but the
  **App Sandbox is the real question** for a clipboard manager: unrestricted
  pasteboard polling, launch-at-login, and the concealed-item checks (SPEC §4.6)
  all need to survive sandbox rules and App Review. A larger commitment than its
  "just ship it" reputation suggests — evaluate the sandbox constraints before
  betting on it, not after.

## Gravity wells to resist

- **Cross-device sync** (CloudKit + conflict resolution). The natural "v2" pull and
  where KISS goes to die — it's a different app, not a feature. Named here only to
  say: don't.
