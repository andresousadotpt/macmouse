# MacMouse

Smooth scrolling and button remapping for third-party mice on macOS.

MacMouse is a small menu-bar app that makes an ordinary USB/Bluetooth mouse feel
at home on a Mac:

- **Smooth scrolling** — wheel notches become a decelerating glide, with
  adjustable smoothness and speed; quick flicks scroll further.
- **Reverse direction** for the mouse wheel only (trackpads untouched).
- **Scroll modifiers** — hold ⇧ for horizontal, ⌥ for precise, ⌃ for fast scrolling, ⌘ to zoom (trackpad-style pinch).
- **Button actions** — click, double/triple click or hold an extra button to trigger
  Mission Control, Application Windows, Show Desktop, Launchpad, Spaces,
  Back/Forward, Middle Click, Look Up, Zoom, Smart Zoom, or any keyboard shortcut you record.
- **Hold-and-drag gestures** — hold a button and move the mouse: up for Mission
  Control, down for Application Windows, left/right to switch Spaces; or grab-and-scroll.
- **Hold-and-scroll** — hold a button and turn the wheel to zoom, scroll
  horizontally, or switch Spaces.
- **Updates** — checks GitHub for new releases, shows a notice, and can install
  them automatically (Settings → General → Updates).

Primary and secondary buttons are never touched, and buttons without an action
behave exactly as before. Everything runs locally; the only network access is the
update check against GitHub Releases (which can be turned off). No telemetry.

Defaults: Button 4/5 = Back/Forward, double-click middle = Mission Control,
hold Button 4 + drag = Spaces & Mission Control, hold Button 5 + scroll = Zoom.

## Install

### Homebrew

```bash
brew tap andresousadotpt/tap
brew install --cask macmouse
```

Then open **MacMouse** and allow it in **System Settings → Privacy & Security →
Accessibility**. MacMouse starts working as soon as access is granted.

If macOS blocks the first launch, right-click the app → **Open**, or use
System Settings → Privacy & Security → **Open Anyway**.

> Releases are signed with a stable self-signed certificate, so Accessibility access
> survives upgrades. Coming from 0.1.x (ad-hoc signed), remove MacMouse from the
> Accessibility list once and enable it again.

### Build from source

```bash
git clone https://github.com/andresousadotpt/macmouse.git
cd macmouse
make app
open dist/macmouse.app
```

Requirements: macOS 14 (Sonoma) or later, Xcode Command Line Tools (full Xcode for `make test`).

## Development

```bash
make build    # debug build
make run      # build and launch via swift run (event tap needs Accessibility for the terminal)
make test     # unit tests for MacMouseCore (requires full Xcode)
make app      # release .app in ./dist/
make clean    # remove build artifacts
```

Settings are stored in `~/Library/Application Support/MacMouse/config.json`.

## How it works

MacMouse installs a session event tap for extra-button and scroll-wheel events.
Line-based wheel events from mice are swallowed and replayed as pixel-precise,
animated scroll events; continuous (trackpad) scrolling passes through. Button
presses go through a small click/hold state machine; system actions are
triggered by pressing the shortcut macOS has bound to them.

MacMouse is a clean-room implementation — see [docs/CLEAN_ROOM.md](docs/CLEAN_ROOM.md).

## Releasing

Version lives in `packaging/Info.plist` (`CFBundleShortVersionString`). Pushing to
`main` runs CI; on success the release workflow auto-bumps the patch version if
needed, builds and signs the app, publishes a GitHub Release zip and updates
the cask in [homebrew-tap](https://github.com/andresousadotpt/homebrew-tap)
(requires the `HOMEBREW_TAP_TOKEN` secret).

Releases are signed with the self-signed certificate in the `SIGNING_CERT_P12`
(base64 `.p12`) and `SIGNING_CERT_PASSWORD` secrets. Keep that certificate: the
in-app updater only installs builds signed by the same certificate as the running
copy, and macOS ties Accessibility access to it. Without the secrets, builds fall
back to ad-hoc signing (no self-update). Local builds sign with
`CODESIGN_IDENTITY="MacMouse Release Signing" make app` when the certificate is
in your keychain.

For a minor/major release: `make bump-version BUMP=minor`, commit `packaging/Info.plist`, push.

## License

MIT — see [LICENSE](LICENSE).
