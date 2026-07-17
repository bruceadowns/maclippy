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
- **Pause** capture with one click (e.g. before copying a password), with the
  menu-bar icon reflecting the paused state.
- Skips items apps mark as sensitive (password managers, etc.).
- Preferences for history size, privacy, launch-at-login, and clip management.

> Menu-bar clip titles are truncated to 36 characters. This is currently
> hard-coded (`ClipMenu.maxItemLength`) and not yet a user preference.

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

To build a standalone copy and keep it around, build the Release configuration
and copy the app bundle:

```sh
xcodebuild -scheme Maclippy -configuration Release -derivedDataPath build build
cp -R build/Build/Products/Release/Maclippy.app ~/Applications/
```

Then launch it:

```sh
open ~/Applications/Maclippy.app
```

Because you built it locally (ad-hoc signed, no quarantine flag), it launches
without Gatekeeper prompts. To update, `git pull` and repeat.

> The app is ad-hoc signed for local use only — it runs on the Mac that built it,
> not as a binary you can hand to someone else. A signed, notarized, downloadable
> release is not available yet.


## Contributing

Simple gitflow: **`develop`** is the default branch, **`main`** the release line.
Accumulate incremental commits on a working branch, then squash-merge it into
`develop` via a PR. Keep `develop` and `main` history clean and meaningful.

## Documentation

See [`SPEC.md`](SPEC.md) for the full design specification and rationale.

## License

[MIT](LICENSE) © 2026 Bruce Downs
