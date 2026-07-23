# Maclippy

A small, open-source macOS menu-bar clipboard manager. It keeps a history of
what you copy and lets you paste any earlier item back with a single click.

Built to be **simple**: it does one thing well and stays out of the way — no
hotkeys to learn, no modes, no dependencies. *What you copied is what you paste.*

> **Status:** early development. Distributed as source — clone and build it
> yourself in Xcode. A signed, downloadable binary is not available yet.

## Features

- Lives in the menu bar — click the icon, click a clip, it's back on your
  clipboard.
- Recent-clip history with a configurable size.
- **Pinned** clips kept in their own section, never auto-evicted.
- **Name a pinned clip to cloak it** — give a pinned clip a custom name (e.g. for
  a password) and the menu shows that name, marked with a 🔑, instead of the
  value. Pasting still copies the real content. Cloaking is a *visual* measure
  only — the value is stored **unencrypted** on disk (see the note below).
- **Hover to peek** — a clip too long for its row shows its full text (up to 500
  chars, real line breaks) in a tooltip on hover, so you can read it without
  pasting. A cloaked clip peeks its name only, never its hidden value.
- **Pause** capture with one click (e.g. before copying a password), with the
  menu-bar icon reflecting the paused state.
- Skips items apps mark as sensitive (password managers, etc.).
- **Clear Formatting** — strip rich (RTF/HTML) styling from the current
  clipboard so the next paste lands as plain text.
- Preferences for history size, privacy, launch-at-login, and clip management
  (pin, rename, reorder, delete).
- **About** panel with version and a link to the project.

> Menu-bar clip titles are truncated to 36 characters (hover a clipped one to
> peek the rest). This is currently hard-coded (`ClipMenu.maxItemLength`) and not
> yet a user preference.

> **Your clips are stored unencrypted.** History lives in a plain SQLite
> database at `~/Library/Application Support/Maclippy/Maclippy.store`, readable by
> anything running as your user. The cloak (🔑) hides a value in the UI, **not**
> on disk. Keep real secrets out of the store — use **Pause** before copying
> them, and rely on the sensitive-item skip — rather than trusting the cloak.
> Encrypting stored values is a planned improvement (see the roadmap).

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16 or later (developed against Xcode 26 / Swift 6)

## Build & run

1. Clone the repo:
   ```sh
   git clone https://github.com/bruceadowns/maclippy.git
   cd maclippy
   ```
2. Open the project in Xcode (`Maclippy.xcodeproj`).
3. Build and run (⌘R). No Apple ID or signing certificate is required — the app
   is ad-hoc signed to run locally on your own Mac.

The app appears in the menu bar — it has no Dock icon or main window.

## Install to ~/Applications

To build a standalone copy and keep it around, use the `Makefile`:

```sh
make install
```

This builds the Release configuration, replaces any copy in `~/Applications`,
and relaunches it. Because you built it locally (ad-hoc signed, no quarantine
flag), it launches without Gatekeeper prompts. To update, `git pull` and repeat.

Other targets: `make run` (Debug build + launch), `make build`, `make lint`,
`make clean`. Run `make help` for the full list.

> The app is ad-hoc signed for local use only — it runs on the Mac that built it,
> not as a binary you can hand to someone else. A signed, notarized, downloadable
> release is not available yet.


## Contributing

Simple gitflow: **`develop`** is the default branch, **`main`** the release line.
Accumulate incremental commits on a working branch, then squash-merge it into
`develop` via a PR. Keep `develop` and `main` history clean and meaningful.

## Documentation

- [`docs/SPEC.md`](docs/SPEC.md) — full design specification and rationale.
- [`docs/roadmap.md`](docs/roadmap.md) — where the project is headed after v1.
- Per-feature specs live alongside it in [`docs/`](docs/):
  [naming a pinned clip](docs/name-pinned-clip.md),
  [the About panel](docs/about-panel.md).

## Inspiration

The menu-bar-only, click-to-paste design takes cues from **CopyClip** by
FIPLAB — a long-running Mac clipboard manager that lives entirely in the menu
bar.

## License

[MIT](LICENSE) © 2026 Bruce Downs
