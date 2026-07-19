# Feature spec — Name (cloak) a pinned clip

**Status:** approved, not yet implemented. Per-feature spec; extends
[`SPEC.md`](SPEC.md), where section references (§) point unless noted.

## 1. Summary

Let the user give a **pinned** clip a custom name that replaces its content
everywhere in the UI. Primary use: cloak a stored password so it never renders
in plaintext in the menu bar, while still pasting the real value verbatim.

## 2. Rationale / KISS fit

- Complements existing privacy features: **Pause** (§4.5) and **Ignore
  concealed** (§4.6) stop *capture*; this keeps the clip but hides its face.
- Scoped to **pinned only** — pinned items are the curated keepers you'd
  deliberately store a secret in; Recent churns and gets evicted, so naming it
  is pointless. This scoping is the KISS boundary, not an arbitrary limit.
- No transformation of content — *what you copied is what you paste* (§4.2)
  still holds; only the *label* changes.

## 3. Data model (§6 change)

Add one field to `Clip`:

```swift
var customLabel: String?   // user-set name; nil = show content-derived label
```

- Non-nil **only on pinned clips**. Invariant: `customLabel != nil ⟹ pinned`.
- Cleared to `nil` on **unpin** — a clip returning to Recent must not carry a
  dead/cloaking name.
- **Capped at 80 characters**, matching `displayTitle`'s `makeTitle` cap (§6),
  so both label sources share one ceiling. The menu's 35-char display
  truncation (§4) still applies on top.
- `displayTitle` keeps its sole meaning (content-derived preview); the Recent
  render path never reads `customLabel`.
- SwiftData lightweight migration (optional, defaults `nil`) — no migration
  plan, no code.

## 4. Menu (§5 change)

- A cloaked pinned entry renders as its `customLabel`, truncated to
  `maxItemLength` (35 + `…`) like any label. Whitespace-reveal is **not** applied
  to custom names. **No glyph or badge** (KISS) — the custom name looks like an
  ordinary named item, which is the point: an indicator (e.g. a key) would draw
  the eye to exactly the secret we're cloaking, and native menus are monochrome
  text anyway. Nothing extra to render or align.
- Clicking still pastes the full stored representations — cloaking is
  display-only.
- Recent entries: unchanged (live whitespace-revealed `plain`).

## 5. Preferences — Clips tab (§7 change)

Rows keep static text labels. The per-row action controls become a uniform
**icon cluster** (pin/unpin, rename, delete), each with **flyover (tooltip)
help** since glyphs alone are ambiguous:

- **Pin / unpin** — icon, state read from the section it's in: Pinned rows show
  `pin.slash` (unpin), Recent rows show `pin` (pin). Tooltip: `Unpin` / `Pin`.
  Replaces today's `Pin`/`Unpin` text button.
- **Rename** — `pencil` icon, **pinned rows only**. Tooltip: `Rename`. Clicking
  turns *that row's* label into an inline editable field — **one open at a
  time**, present only while editing, so rows are otherwise static text (no
  persistent column of edit boxes). The field prefills with the current
  `customLabel`, or is empty with the content-derived `displayTitle` as
  placeholder when unnamed (so you can see what you're naming). Commit on Enter
  or focus loss returns to static text; an empty / whitespace-only value sets
  `customLabel` back to `nil`. Input is capped at 80 characters (§3).
- **Delete** — `trash` icon (unchanged). Tooltip: `Delete`.
- **No cloaked-state glyph.** A named row already reads as a human label vs an
  unnamed row's raw content; a leading indicator would be redundant and would
  misalign named vs unnamed rows. (If ambiguity ever bites, revisit with a
  monochrome `key` SF Symbol — not an emoji — to match the action icons.)
- **Recent rows**: `pin` + `trash` only — no rename (naming is pinned-only).
- Unpinning a named clip clears its name (per the model invariant, §3).

## 6. Known limitation

Between copying a secret and naming it, the content is visible in the menu and
Recent list (it's a normal clip until pinned **and** named). Documented, not
solved here — Pause / Ignore-concealed cover the "never capture" case.

## 7. Out of scope (this feature)

- **Right-click / in-menu rename.** The menu is a native `NSMenu`
  (`MenuBarExtra` `.menu` style); its rows are `NSMenuItem`s that don't receive
  context-menu events, and a text-editing session can't live inside an open
  `NSMenu` (it dismisses on focus loss). In-menu editing would require switching
  the extra to `.window` style and re-implementing the whole menu as a custom
  SwiftUI view — a separate spec, not this one. Rename stays in Preferences →
  Clips, consistent with pin/delete (§5).
- Naming Recent (unpinned) clips.
- Masking the stored `plain` at rest / encryption.
- Hiding the content preview *before* naming.

## 8. Implementation touchpoints

Code (see architecture in `CLAUDE.md`):

- `Model/Clip.swift` — add `customLabel: String?` (init to `nil`).
- `Views/ClipMenu.swift` — `label(for:)` returns `customLabel` (truncated, no
  whitespace-reveal) for cloaked pinned entries; unchanged otherwise.
- `Views/ClipsSettingsView.swift` — pin/unpin → icon; add pencil rename (inline
  edit, pinned only) and tooltips; clear `customLabel` in the unpin path.

`ClipboardMonitor.reload()` filters/sorts are unaffected (`customLabel` doesn't
change ordering). No new bulk mutation, so no extra `reload()` wiring.

Docs to fold in once built:

- `docs/SPEC.md` — §6 model field, §5 menu (custom label, no glyph), §7 Clips
  tab (icon cluster + rename).

No tests (no test target). No new assets — stock SF Symbols only.
