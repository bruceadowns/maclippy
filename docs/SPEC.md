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
- **Unpinning bumps recency:** an unpinned clip re-enters Recent at the top
  (`dateRecorded = .now`), like reuse — so it isn't dropped at its stale age
  where trimming would evict it immediately.
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
Pause Maclippy                    ← "Resume Maclippy" while paused
─────────────────────────         ← divider: commands │ clips
📌 Pinned                         ← click-to-paste; not editable here
   • Work email signature
   • Standup message
─────────────────────────         ← divider: pinned │ recent
🕐 Recent                          ← click-to-paste
   • clip just now
   • clip a minute ago
   • …
─────────────────────────         ← divider: clips │ app
About Maclippy                    ← system standard About panel
Preferences…
Quit Maclippy
```

- Three dividers: **commands ↔ clips**, **pinned ↔ recent**, and **clips ↔ app**.
- **Top = act now, middle = pick a clip, bottom = app.** The two safe, frequent
  commands (Clear Formatting, Pause) sit at the top for quick access; the bottom
  is the standard macOS trio (About / Preferences / Quit).
- **Clear Unpinned History is not in the menu.** It's destructive, rare, and
  undo-less, so it lives only in Preferences → General (§7) with a confirm —
  deliberately not one careless click away in the primary menu.
- Rows are pure click-to-paste. Pin/unpin/rename/reorder/delete happen in
  Preferences, not in the menu (a plain `NSMenu` item can't both fire an action
  and host a submenu).
- **Ellipsis convention:** items opening a dialog get `…` (`Preferences…`).
  Immediate actions do not (`Pause`, `Clear Formatting`, `Quit`). **Exception:**
  `About Maclippy` opens the standard About panel but takes no `…`, per Apple's
  convention for "About <App>". See [`about-panel.md`](about-panel.md).
- **Empty states:**
  - No pinned items → hide the Pinned section **and** its divider; menu opens
    straight into Recent.
  - No clips at all → a disabled `No clips yet` placeholder row.
- **Dividers-only** — no text header rows. The pin glyph signals the pinned zone;
  dividers separate commands ↔ pinned ↔ recent ↔ app. Keeps the menu compact.
- **Row labels** derive from `plain`, truncated to **36 characters**
  (`ClipMenu.maxItemLength`, hard-coded) with a trailing `…`. Leading/trailing
  whitespace is revealed with glyphs (`·` space, `⇥` tab, `⏎` newline) so
  verbatim-distinct clips don't render identically; interior whitespace stays
  literal. The reveal is `Clip.revealedPlain`, shared with the Clips tab (§7) so
  the two surfaces label identically. It processes at most `maxRevealChars`
  (1024) of `plain`, so labelling a 2 MB clip never scans the whole payload —
  everything past that cap is invisible anyway (label 36, peek 500).
- A pinned clip with a `customLabel` (§6) shows that name instead — truncated
  the same way, no whitespace-reveal, prefixed with a `key.fill` glyph marking it
  as a named item. Cloaking means the plaintext is never shown (§6); the key
  reveals nothing about the content.
- **Hover tooltip (peek).** A row whose label is actually clipped (source > 36
  chars) carries a `.help` tooltip so a long clip is legible without pasting it.
  Unlike the one-line row label, the peek shows the clip **verbatim** — real line
  breaks and spaces, no `⏎`/`·`/`⇥` glyph reveal — because a tooltip isn't
  constrained to one line and a multi-line clip (code, an address) reads far
  better this way. Whitespace-reveal stays the *label's* job (its disambiguation
  surface); the tooltip's job is legibility. Rows that already fit get no tooltip.
  The peek is capped at **500 chars** (`ClipMenu.maxPeekLength`): a clip can be up
  to 2 MB (§4.3) and handing that whole string to a tooltip janks AppKit's layout
  — the cap and the fit-check use index math, never an O(n) `.count`/scan. A
  cloaked clip peeks its `customLabel` only, **never** its hidden payload.
  Appearance and delay are the system's (`NSInitialToolTipDelay`); Maclippy sets
  neither.

---

## 6. Data model

```swift
@Model
final class Clip {
    var id: UUID
    var dateRecorded: Date
    var pinned: Bool
    var pinnedOrder: Int        // ordering among pinned items
    var displayTitle: String    // cleaned text; seeds the rename field
    var customLabel: String?    // user-set name that cloaks content (pinned only)
    var plain: String           // always present
    var rtf: Data?              // optional rich representation
    var html: String?           // optional rich representation
}
```

- Text-only in v1 — no images, no files. Small payloads, stored inline (no
  external blob files).
- **Store location:** a SwiftData/SQLite store at
  `~/Library/Application Support/Maclippy/Maclippy.store` (+ `-wal`/`-shm`). The
  container is given an explicit `ModelConfiguration` URL so the app **namespaces**
  its store under `Maclippy/` instead of SwiftData's bare `default.store` in the
  shared Application Support root (which collides by name with any other SwiftData
  app). Not sandboxed — `LSUIElement` agent, no App Sandbox.
- `displayTitle` is derived from `plain` (trimmed, first line, ≤80 chars). It's
  the **clean seed for the rename field** (and its placeholder) — never a row
  label. Both the **menu** and the **Settings clips list** label unnamed clips
  from `Clip.revealedPlain` (whitespace-revealed `plain`; the menu adds a 36-char
  cap, the list relies on line truncation — see §5, §7), so the two agree.
- `customLabel` is a user-set name that **replaces** the content-derived label in
  both the menu and the clips list — its purpose is *cloaking* a stored secret
  (e.g. a password) so the plaintext never shows in the menu bar. Set **only on
  pinned clips**, cleared on unpin, capped at 80 chars. `nil` = show the derived
  label. Paste-back is unaffected — the real `plain` is always what's copied.
  Full design: [`name-pinned-clip.md`](name-pinned-clip.md).

> **At-rest storage is not encrypted — by design in v1.** Cloaking is a
> *visual* measure: `customLabel` hides a secret from the menu bar and Settings
> list, but the payload is stored as plaintext in the store above
> (`~/Library/Application Support/Maclippy/Maclippy.store`), readable by anything
> running as your user (e.g. `sqlite3 … "SELECT ZPLAIN FROM ZCLIP"`). This is an accepted v1
> trade-off (KISS; no Keychain/crypto dependency), **not** an oversight. If you
> store passwords in a cloaked clip, understand they live unencrypted at rest —
> the concealed-item filter (§4.6) and Pause (§4.5) exist so most secrets never
> enter the store in the first place. Encrypting the payload is a tracked future
> item (see [`roadmap.md`](roadmap.md)).

### Inspecting the store (developers)

The store is a plain SQLite file — inspect it with the `sqlite3` CLI while the app
is running (WAL mode allows concurrent reads). The one entity, `Clip`, maps to
table **`ZCLIP`**; the `Z`/`Z_` prefixes are Core Data's (SwiftData is built on
it), and each attribute is a `Z`-prefixed column (`ZPLAIN`, `ZPINNED`,
`ZCUSTOMLABEL`, …). The other tables (`Z_PRIMARYKEY`, `Z_METADATA`, `ACHANGE`,
`ATRANSACTION`, …) are framework bookkeeping and persistent-history tracking — not
ours.

```sh
DB=~/Library/"Application Support"/Maclippy/Maclippy.store

sqlite3 "$DB" ".tables"                 # list tables
sqlite3 "$DB" ".schema ZCLIP"           # column layout
sqlite3 "$DB" "SELECT count(*) FROM ZCLIP;"

# pinned first, then recent; preview the (plaintext) payload
sqlite3 -header -column "$DB" \
  "SELECT ZPINNED AS pin, ZPINNEDORDER AS ord, COALESCE(ZCUSTOMLABEL,'') AS label,
          substr(ZPLAIN,1,60) AS preview
   FROM ZCLIP ORDER BY ZPINNED DESC, ZPINNEDORDER, ZDATERECORDED DESC;"
```

Read-only is safe; **don't write** to the store behind the app — SwiftData owns
the schema and won't see external mutations. Note `SELECT ZPLAIN …` returns
cloaked values in cleartext, which is the at-rest exposure described above.

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
- **Clear History (except pinned)…** — button with confirm. Clears the
  **Recent** list only; **pinned always survives**. Confirmation dialog:
  `"Clear recent clips?" — "Pinned items are kept."  [Clear] [Cancel]`. This is
  the **only** place the action lives (not in the menu — see §5).

### Clips
- List of all clips (pinned + recent). Per-row actions are icon buttons with
  tooltip help: **pin/unpin**, **rename** (pinned only), **delete**.
- Row labels use `Clip.revealedPlain` — the same whitespace-reveal as the menu
  (§5), so `"foo"` and `" foo "` read as distinct here too. A named clip shows
  its `customLabel` verbatim (no reveal) with the `key.fill` glyph.
- **Pin / unpin.** Unpinning clears any `customLabel` (§6).
- **Rename** (pinned only) — sets a `customLabel` that cloaks the clip. The
  pencil turns that one row's label into an inline field (one at a time),
  committing on Enter or focus loss; empty reverts to the derived label. See
  [`name-pinned-clip.md`](name-pinned-clip.md).
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

### Limits (reference)

Every numeric cap in one place. All hardcoded except history size.

| Limit | Value | Constant / source |
|---|---|---|
| Menu row label | 36 chars + `…` | `ClipMenu.maxItemLength` |
| Tooltip peek | 500 chars + `…`, verbatim (real newlines) | `ClipMenu.maxPeekLength` |
| Reveal scan bound | ≤ 1024 chars of `plain` processed | `Clip.maxRevealChars` (§5) |
| Clips-tab row label | single line, view-truncated | `.lineLimit(1)` |
| `customLabel` (cloak name) | 80 chars | `Clip.maxLabelLength` |
| `displayTitle` (rename seed) | 80 chars, first line, trimmed | `Clip.maxLabelLength` |
| Max clip payload | 2 MB (degrade, don't truncate) | §4.3 |
| History size | 0–99, default 20; 0 = unlimited | Preference (§7 General) |
| Poll interval | 0.3s | §4.1 |

The 500 (tooltip) and 1024 (reveal scan) caps are performance bounds — they cap
work, not what a clip may contain; a clip's full payload is always pasted intact.

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
