# Feature spec — Name (cloak) a pinned clip

**Status:** implemented. Per-feature spec; extends
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

**What "cloaking" means here:** the goal is narrow — *never display the
password's plaintext in plain sight*. It is **not** hiding that a stored item
exists or that it's named. So a `key` indicator marking a named item is fully
compatible with cloaking (and shown in both menu and dialog): it reveals nothing
about the content. No encryption or at-rest masking is implied.

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
  `maxItemLength` (35 + `…`) like any label, prefixed with a `key.fill` SF Symbol
  (via `Label`) marking it as a named item. Whitespace-reveal is **not** applied
  to custom names. The key reveals nothing about the content, so it's compatible
  with cloaking (§2) and consistent with the dialog's indicator (§5). (Note: SF
  Symbols don't always render on `.menu`-style `MenuBarExtra` items; verified in
  a build.)
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
  persistent column of edit boxes). The field is seeded with the current label —
  the `customLabel` if named, otherwise the content-derived `displayTitle` — so
  you edit from the current value. Commit on Enter
  or focus loss returns to static text. Three things clear `customLabel` back to
  `nil` (uncloak): an empty / whitespace-only value, **or** a value equal to the
  clip's real content (`plain`) — naming a clip after its own content cloaks
  nothing. Committing the seeded value **unchanged** is a no-op, identical to
  Esc — so accepting an unnamed clip's `displayTitle` without editing leaves it
  unnamed rather than saving the title as a name. **Esc** abandons the edit and
  reverts to the stored name (nothing saved). Input is capped at 80 characters (§3).
- **No duplicate labels.** A name that matches another **pinned** clip's
  `customLabel` (case-insensitive) is rejected — `NSSound.beep()`, revert, nothing
  saved (same terminal state as Esc), on both the Enter and focus-loss paths. Two
  clips with the same cloaking name are indistinguishable in the menu (no
  whitespace-reveal on custom names, both keyed), so clicking the wrong one pastes
  the wrong secret silently — the one collision worth blocking. Enforceable
  precisely *because* pinned labels are a fixed set edited only here.
  **Not** guarded: a label equal to some *other* clip's content (`plain`). That's
  a different, weaker case — the real clip carries no `key.fill`, so the two stay
  distinguishable — and it's unenforceable anyway (Recent churns every poll; a new
  copy matching an existing label would need policing at capture, against §7/§9
  KISS). Enforced-at-edit-but-not-at-capture would be a rule in appearance only.
- **Delete** — `trash` icon (unchanged). Tooltip: `Delete`.
- **Named indicator.** A named row shows a small monochrome `key.fill` SF Symbol
  (secondary, caption-sized) before its label — enough to tell "I named this"
  from raw content at a glance, without a text toggle. The slot is reserved on
  every row (invisible when unnamed) so labels stay aligned. Same `key.fill` as
  the menu (§4) for consistency; an SF Symbol, not an emoji.
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

- `docs/SPEC.md` — §6 model field, §5 menu (custom label + `key.fill`), §7 Clips
  tab (icon cluster + rename).

No tests (no test target). No new assets — stock SF Symbols only.

## 9. Migration

- **Forward (upgrade to this feature): automatic.** `customLabel` is a new
  *optional* attribute, so SwiftData runs lightweight migration on first launch —
  existing clips get `customLabel = nil`. No `VersionedSchema` / `MigrationPlan`
  or code needed.
- **Backward (rolling back to a pre-feature build): unsupported — it crashes.**
  Once a newer build opens the store, SwiftData migrates its schema and the
  `Clip` entity's version hash changes. An older binary's model no longer
  matches, so `ModelContainer(for: Clip.self)` throws
  `NSPersistentStoreIncompatibleVersionHashError`; the `catch` in
  `MaclippyApp.init()` is a `fatalError`, so the old app dies on launch. (This
  `fatalError` predates the feature — backward rollback was never supported.)
  Any names set under the new schema are lost regardless, as the old schema has
  no column for them.

  **Workaround:** delete the store and relaunch (loses clip history):

  ```sh
  rm -rf ~/Library/Application\ Support/*/default.store*   # in the app's container
  ```

  Left as-is deliberately: softening the `fatalError` to recreate the store on
  incompatibility would trade a loud crash for a silent history wipe — worse for
  a build-it-yourself, single-local-store app.
