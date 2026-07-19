# Maclippy — Specification

An open-source macOS menu-bar clipboard manager. Keeps a history of what you
copy and lets you paste any earlier item back with a single click. A small,
modern, dependency-free SwiftUI app.

---

## 1. Product summary

- **What it is:** a menu-bar-only utility that watches the system clipboard,
  stores recent text clips, and re-copies a chosen clip on click.
- **Who it's for (v1):** developers comfortable cloning a repo and building in
  Xcode. Source-only distribution; no signed binary yet.

### Goal & philosophy — KISS

Maclippy is built to **Keep It Simple, Stupid**: a clipboard manager that does
one thing well and stays out of the way, not a feature kitchen sink. Every
decision here follows that lens; future changes should too.

- **No decisions about your content** — *what you copied is what you paste.* No
  transformation, no interpretation.
- **One interaction** — click the icon, click a clip. No hotkeys, modifiers, or
  modes.
- **Hardcode over configure** — a knob nobody should touch is a footgun (see
  §7); Preferences holds only what genuinely varies between users.
- **No dependencies or background machinery** beyond what the feature needs.
- **Graceful, never surprising** — degrade (drop rich → keep plain) rather than
  fail; protect pinned items; confirm destructive actions.
- **Defer, don't pre-build** — richer features stay out of scope until there's a
  real need (see §9).

When in doubt, choose the simpler option. Complexity must earn its place.

---

## 2. Platform & distribution

| Item | Decision |
|---|---|
| Minimum macOS | **14.0 (Sonoma)** |
| Built/tested on | macOS 26, Xcode 26.4, Swift 6.3 |
| IDE | **Xcode** (`.xcodeproj`) |
| Distribution (v1) | **Source on GitHub — clone and build yourself** |
| Code signing | **Ad-hoc** (`CODE_SIGN_IDENTITY = "-"`, manual). No Apple ID, certificate, team, Developer ID, or notarization. |
| Auto-update | **Deferred** (see §9). No Sparkle in v1. |
| Dependencies | **None.** System frameworks only. |

Rationale: build-it-yourself sidesteps the entire signing / notarization /
release-pipeline chain. The cost — a developer audience only — is acceptable
for v1.

**Ad-hoc signing.** The project is configured to sign ad-hoc so a fresh clone
builds and runs with **zero setup** — no Apple ID, code-signing certificate, or
Development Team. A locally built app has no quarantine flag, so Gatekeeper runs
it without complaint. The trade-off aligns with the distribution model: an
ad-hoc app runs on the machine that built it but is not distributable as a binary
to other Macs. Real Developer ID signing + notarization returns only with a
downloadable binary release (see §9).

---

## 3. Technology stack

All Apple system frameworks; no third-party packages.

| Concern | Framework / API |
|---|---|
| App lifecycle & UI | SwiftUI — `@main App`, `MenuBarExtra` (`.menu` style), `Settings` scene |
| Menu / clipboard interop | AppKit — `NSMenu`, `NSMenuItem`, `NSPasteboard` |
| Persistence | **SwiftData** |
| Launch at login | ServiceManagement — `SMAppService.mainApp` |

- **App type:** menu-bar agent — `LSUIElement = 1` (no Dock icon, no main window).
- **Bundle id:** `com.github.bruceadowns.maclippy`.

---

## 4. Core behavior

### 4.1 Clipboard capture

- macOS has **no clipboard-change notification** — the app **polls**.
- Timer polls `NSPasteboard.general.changeCount` every **0.3s** (hardcoded, not
  a preference). Comparing the integer is cheap; real work only happens when the
  count changes.
- On a change, capture **text representations**:
  - `plain` (`public.utf8-plain-text`) — always required; drives menu and list labels.
  - `rtf` (`public.rtf`) — optional, stored when present.
  - `html` (`public.html`) — optional, stored when present.
- **Self-capture suppression:** the app records the `changeCount` produced by its
  own paste-back write and skips it, so re-copying a clip doesn't re-record it.
- **Skips empty / whitespace-only** content — nothing worth storing.
- **De-dupes by verbatim `plain`:** re-copying content already in history bumps
  its `dateRecorded` to the top instead of inserting a duplicate. Matching is
  exact — `"foo"` and `" foo "` are distinct clips.

### 4.2 "What you copied is what you paste"

- No format interpretation, no transformation, no plain-vs-rich preference.
- **Paste-back:** `clearContents()`, then write back every stored representation
  so the destination app picks the richest it understands.
- Faithful to standard text types; app-private/proprietary pasteboard flavors are
  **not** promised to round-trip.

### 4.3 Max clip size (hardcoded 2 MB)

Guardrail against one pathological clip bloating the store. On overflow, degrade
gracefully — **never truncate**:

1. Under 2 MB → store everything (plain + rtf + html).
2. Over 2 MB → **drop the rich representations, keep plain.**
3. Plain alone still over 2 MB → **skip the clip entirely.**

### 4.4 Ordering & pinning

- **Recency:** recent clips sorted by `dateRecorded` descending.
- **Pinned:** a separate section, always shown above recent, ordered by
  `pinnedOrder`.
- **Pinned items are never auto-evicted** and are exempt from Clear History.
- **History trimming:** when recent-clip count exceeds the configured history
  size, evict oldest first. Pinned excluded from the count and from eviction.

### 4.5 Pause / Resume capture

- A menu toggle stops capturing new clips (existing history untouched). Primary
  use: flip off before copying a password, flip back on.
- **Menu bar icon reflects state:** the teal clipboard glyph turns gray while
  paused, so the paused state is glanceable.
- **Not persisted** — the app **always starts capturing on launch**, so a
  forgotten pause can't silently disable the app across restarts.

### 4.6 Privacy — ignore concealed items

- On capture, inspect `NSPasteboard.types` and skip items marked sensitive:
  - `org.nspasteboard.ConcealedType`
  - `org.nspasteboard.TransientType`
  - `com.apple.is-sensitive`
- Governed by a preference, **default ON**.
- Complements Pause: the marker covers cooperating apps (password managers);
  Pause covers everything else.

### 4.7 No hotkeys / no keyboard shortcuts (v1)

- No global hotkeys (no Carbon, no shortcut-recorder UI).
- No ⌘1–⌘0 quick-select accelerators.
- No auto-paste / focus manipulation — a picked clip lands on the pasteboard and
  the user pastes with the system's own ⌘V wherever they are. (No Accessibility
  permission required.)
- `⌘,` for Preferences is provided automatically by the `Settings` scene and is
  treated as a system convention, not a feature.

### 4.8 Clear formatting (menu action)

- A **Clear Formatting** menu item rewrites the current system pasteboard to its
  plain-text representation only, dropping rich (rtf/html) flavors so the next
  paste lands unstyled.
- Acts on the **live pasteboard**, not stored history. This is a user-initiated
  transformation, so it doesn't contradict the *automatic* "what you copied is
  what you paste" rule (§4.2) — the user asked for it.
- Immediate action, no confirmation; no-op when the pasteboard holds no text.

---

## 5. Menu structure

```
Clear Formatting                  ← acts on the current clipboard
─────────────────────────         ← divider: action │ clips
📌 Pinned                         ← click-to-paste; not editable here
   • Work email signature
   • Standup message
─────────────────────────         ← divider: pinned │ recent
🕐 Recent                          ← click-to-paste
   • clip just now
   • clip a minute ago
   • …
─────────────────────────         ← divider: clips │ actions
Pause Maclippy                    ← "Resume Maclippy" while paused
Clear Unpinned History…
Preferences…
Quit Maclippy
```

- Three dividers: **Clear Formatting ↔ clips**, **pinned ↔ recent**, and **clips ↔ actions**.
- Rows are pure click-to-paste. Pin/unpin/reorder/delete happen in Preferences,
  not in the menu (a plain `NSMenu` item can't both fire an action and host a
  submenu).
- **Ellipsis convention:** items opening a dialog get `…` (`Clear Unpinned
  History…`, `Preferences…`). Immediate actions do not (`Pause`, `Clear
  Formatting`, `Quit`).
- **Empty states:**
  - No pinned items → hide the Pinned section **and** its divider; menu opens
    straight into Recent.
  - No clips at all → a disabled `No clips yet` placeholder row.
- **Dividers-only** — no text header rows. The pin glyph signals the pinned zone;
  dividers separate pinned ↔ recent ↔ actions. Keeps the menu compact.
- **Row labels** derive from `plain`, truncated to **36 characters**
  (`ClipMenu.maxItemLength`, hard-coded) with a trailing `…`. Leading/trailing
  whitespace is revealed with glyphs (`·` space, `⇥` tab, `⏎` newline) so
  verbatim-distinct clips don't render identically; interior whitespace stays
  literal.

### 5.1 Clear Unpinned History

- Clears the **Recent** list only; **pinned always survives**.
- Shows a confirmation dialog before clearing:
  `"Clear recent clips?" — "Pinned items are kept."  [Clear] [Cancel]`

---

## 6. Data model

```swift
@Model
final class Clip {
    var id: UUID
    var dateRecorded: Date
    var pinned: Bool
    var pinnedOrder: Int        // ordering among pinned items
    var displayTitle: String    // cleaned label shown in the menu
    var plain: String           // always present
    var rtf: Data?              // optional rich representation
    var html: String?           // optional rich representation
}
```

- Text-only in v1 — no images, no files. Small payloads, stored inline (no
  external blob files).
- `displayTitle` is derived from `plain` (trimmed, first line, ≤80 chars) and
  labels the **Settings clips list**. The **menu** builds its own label from
  `plain` live (whitespace-revealed, 36-char — see §5).

---

## 7. Preferences

SwiftUI `Settings` scene, a `TabView` with two tabs.

### General
- **History size** — max recent clips to keep, **0–99** (field + stepper).
  Default **20**; **0 means unlimited** (`trim()` no-ops). Lowering it trims the
  store immediately.
- **Ignore concealed items** — toggle. Default **ON**.
- **Launch at login** — toggle, backed by `SMAppService.mainApp`
  (`register()` / `unregister()`; reflect `.status` when the window appears).
- **Clear History (except pinned)…** — button with confirm.

### Clips
- List of all clips (pinned + recent).
- **Pin / unpin.**
- **Drag to reorder** pinned items.
- **Delete** an individual clip (no confirm — single deletes are trivially
  re-copyable; only bulk Clear History confirms).

Settings persist via `@AppStorage` (UserDefaults).

### Not exposed (hardcoded in v1)

Intentionally fixed. If a real need arises, each could become a preference — its
current value is the default it would ship with.

| Behavior | Current value | Why fixed |
|---|---|---|
| Poll interval | 0.3s | No value a user should tune. |
| Max clip size | 2 MB | Guardrail, not a knob (see §4.3). |
| Capture on launch | Always on; pause state not persisted | A forgotten pause must not disable the app (see §4.5). |
| Paste format | Faithful — all stored representations | *What you copied is what you paste* (see §4.2). |

---

## 8. Repository scaffolding

- **`README.md`** — description, build steps (clone → open `.xcodeproj` → Run;
  ad-hoc signed, no team needed), macOS 14+ requirement.
- **`LICENSE`** — **MIT**.
- **`.gitignore`** — standard Swift/Xcode (`build/`, `DerivedData/`,
  `xcuserdata/`, etc.).
- **`docs/SPEC.md`** — this document. Per-feature specs live alongside it in `docs/`.
- **`Makefile`** — CLI wrappers for the Xcode build (`make build [CONFIG=Release]`,
  `run`, `lint`, `install`, `clean`).
- **`CLAUDE.md`** — guidance for AI assistants working in the repo.

---

## 9. Out of scope for v1 (future candidates)

- Image and file capture (model would add a `type` + external blob storage).
- Rich-text paste-format control (global preference or ⌥-to-paste-plain gesture).
- Global hotkeys and ⌘1–⌘0 quick-select.
- Auto-paste into the active app (needs focus restore + Accessibility permission).
- **Sparkle auto-update** — a release-day task, added alongside Developer ID
  signing + notarization + GitHub Releases hosting, not before.
- Trim leading/trailing whitespace on capture (a preference; default off — clips
  are stored and matched verbatim today).
- Per-app exclusion list.
- Source-app tracking (which app a clip came from).
- Usage/frequency ranking (`totalPastes`-style).
- Signed/notarized binary distribution.

---

## 10. Open items

None — spec is complete.
