# AGENTS.md

Instructions for AI coding agents working on a **macOS Swift app** bootstrapped from **macskeleton**.

## Project overview

- **What this is:** MacMouse — a menu-bar app adding smooth scrolling and button remapping for third-party mice.
- **Platform:** macOS 14 (Sonoma) or later. Swift Package Manager project; no Xcode project file.
- **License:** MIT
- **Template repo:** https://github.com/andresousadotpt/macskeleton
- **Clean room:** this is an independent implementation. Do **not** copy code, assets,
  strings, constants or config from other mouse utilities (including decompiled output).
  Work from `docs/CLEAN_ROOM.md` and Apple's public docs. Update that spec when adding features.
  The only exception is the macOS gesture-event interface table in that file (event types,
  field numbers, phases), recorded from a decompiled helper with the owner's approval.

## MacMouse specifics

| Piece | File | Notes |
|-------|------|-------|
| Config model | `Sources/MacMouseCore/Models/MouseConfig.swift` | Codable; buttons are 1-based (3 = middle) |
| Click/hold recognition | `Sources/MacMouseCore/Logic/ClickRecognizer.swift` | Pure state machine, time injected |
| Smooth scroll | `Sources/MacMouseCore/Logic/ScrollAnimator.swift` | Exponential decay, sub-pixel carry |
| Event tap | `Sources/MacMouse/Support/MouseEngine.swift` | Main run loop; returns pass/swallow |
| Synthetic events | `Sources/MacMouse/Support/EventPoster.swift` | Tags events so the tap ignores them |
| System actions | `Sources/MacMouse/Support/SymbolicHotKeys.swift` | Runtime-resolved window-server calls |
| Release parsing | `Sources/MacMouseCore/Models/AppRelease.swift` | Version compare, GitHub JSON |
| Self-update | `Sources/MacMouse/Support/Updater.swift` | Download, verify signature, swap, relaunch |

Runtime gotchas:

1. The event tap only works with **Accessibility** access. `make run` needs it granted to the
   terminal; `make app` builds need it granted to `macmouse.app`.
2. Ad-hoc signatures change every build, so macOS may require re-granting Accessibility after rebuilding.
   Releases are signed with a stable self-signed certificate (`SIGNING_CERT_P12` /
   `SIGNING_CERT_PASSWORD` secrets, `CODESIGN_IDENTITY` in `build-app.sh`), which keeps
   Accessibility across upgrades and lets the updater verify downloads. Never rotate it casually.
3. Never intercept buttons 1–2, and pass through any event `MouseConfig.intercepts` rejects.
4. Config decoding is tolerant (missing keys → defaults). Keep it that way when adding fields.

## Bootstrap checklist (new app from skeleton)

When creating a new app, update **all** of the following. Keep names consistent across files.

| Step | File / path | What to change |
| ---- | ----------- | -------------- |
| 1 | `packaging/app.env` | All identity variables (primary config for CI + packaging) |
| 2 | `packaging/Info.plist` | `CFBundleName`, `CFBundleDisplayName`, `CFBundleExecutable`, `CFBundleIdentifier`, copyright |
| 3 | `Package.swift` | Package name, product name, target names |
| 4 | `Sources/MacMouse/` → `Sources/{AppName}/` | Rename directory and `@main` app file |
| 5 | `Sources/MacMouseCore/` → `Sources/{AppName}Core/` | Rename directory |
| 6 | `Tests/MacMouseCoreTests/` → `Tests/{AppName}CoreTests/` | Rename directory and imports |
| 7 | `README.md` | App name, description, install URLs |
| 8 | `CHANGELOG.md` | App name and initial release notes |
| 9 | `.github/ISSUE_TEMPLATE/config.yml` | Support/security URLs (if repo URL changed) |
| 10 | GitHub repo | Create new repo; add `HOMEBREW_TAP_TOKEN` secret for releases |

### `packaging/app.env` reference

```bash
APP_BUNDLE_NAME=macmouse          # dist/macmouse.app (lowercase bundle folder)
APP_EXECUTABLE=MacMouse           # SPM executable target; also CFBundleExecutable
APP_PACKAGE=MacMouse              # Package.swift name
APP_CORE=MacMouseCore             # Core target name
APP_DISPLAY_NAME=MacMouse         # Human-readable name (Homebrew cask)
APP_BUNDLE_ID=pt.andresousa.macmouse
APP_SUPPORT_DIR=MacMouse          # ~/Library/Application Support/MacMouse
GITHUB_OWNER=andresousadotpt
GITHUB_REPO=macmouse              # GitHub repo name (not full URL)
CASK_NAME=macmouse                # Homebrew cask name
HOMEBREW_TAP=andresousadotpt/homebrew-tap
```

**Do not rename** `Makefile`, `packaging/build-app.sh`, `packaging/bump-version.sh`, or workflow files — they read from `app.env`.

After bootstrap:

```bash
make build && make test && make app
```

## Architecture

Two Swift targets with strict separation of concerns:

| Target | Role | Depends on |
|--------|------|------------|
| **MacMouseCore** | Models, persistence, pure logic (no UI) | Foundation only |
| **MacMouse** | SwiftUI views, AppKit bridges, app shell | MacMouseCore |

```
Sources/
├── MacMouseCore/          # Testable, UI-free core
│   ├── Models/
│   ├── Services/
│   └── Utilities/
└── MacMouse/              # macOS app shell
    ├── MacMouseApp.swift  # @main entry
    ├── ViewModels/
    ├── Views/
    ├── Support/        # AppKit bridges
    └── Resources/      # Logo.png (optional; auto-generates icon if missing)
```

### Key design choices

- **View models** should use `@MainActor @Observable` (Observation framework, not Combine).
- **Persistence** should use `actor` types for thread-safe file I/O when you add storage.
- **File writes** should go through atomic write helpers — never write user data files directly in place.
- **App config** typically lives at `~/Library/Application Support/{APP_SUPPORT_DIR}/`.

### UI stack

- **SwiftUI** for windows and settings.
- **AppKit** only where SwiftUI is insufficient (`NSViewRepresentable`, menu bar, custom text views).

## Build and run

All commands run from the repo root:

```bash
make build    # swift build (debug)
make run      # build + swift run (uses APP_EXECUTABLE from app.env)
make test     # swift test — requires full Xcode, not Command Line Tools alone
make app      # release .app bundle in ./dist/
make clean    # remove .build/ and dist/
```

### Important runtime gotchas

1. **Features that require a `.app` bundle** (notifications, some entitlements) only work after `make app`, not `make run` / `swift run`.
2. **Version source of truth:** `packaging/Info.plist` (`CFBundleShortVersionString`).

## Testing

Tests live in `Tests/MacMouseCoreTests/` and target **MacMouseCore only**. UI and AppKit code is not unit-tested.

```bash
make test
swift test --filter MacMouseCoreTests.testMarketingVersionIsNonEmpty
```

Use temporary directories for file I/O tests and clean up in `defer`. Prefer deterministic dates over `Date()` when testing time-based logic.

## Code style and conventions

### Swift language

- **Swift tools version:** 6.0 (`Package.swift`).
- **Minimum deployment:** macOS 14.
- Prefer `Sendable`, `Codable`, and `Equatable` on models in MacMouseCore.
- Use `public` on MacMouseCore types consumed by the app target.
- Mark UI-only types `internal` (default) in MacMouse.

### Naming and organization

- New **models/settings** → `Sources/MacMouseCore/Models/`
- New **file I/O or config logic** → `Sources/MacMouseCore/Services/` or `Utilities/`
- New **screens** → `Sources/MacMouse/Views/`
- New **AppKit bridges** → `Sources/MacMouse/Support/`

### Patterns to avoid

- Do not add UI imports (`SwiftUI`, `AppKit`) to MacMouseCore.
- Do not add heavy dependencies without strong justification.
- Minimize scope: match existing style, don't refactor unrelated code.

## Packaging and release

| File | Purpose |
|------|---------|
| `packaging/app.env` | App identity — CI and build scripts source this |
| `packaging/build-app.sh` | Assembles `dist/{APP_BUNDLE_NAME}.app` |
| `packaging/Info.plist` | Bundle metadata; version source of truth |
| `packaging/App.entitlements` | Sandbox/entitlements for the bundle |
| `packaging/bump-version.sh` | Bumps patch/minor/major in Info.plist |
| `packaging/cask.rb.template` | Homebrew cask template (CI fills version/sha256) |
| `packaging/generate-icon.swift` | Generates AppIcon when Logo.png is missing |
| `.github/workflows/ci.yml` | Build + test on push/PR |
| `.github/workflows/release.yml` | Version bump, build, GitHub Release, Homebrew tap |

### Release flow

1. **Patch releases:** merge to `main`; CI auto-bumps if tag `v{version}` already exists.
2. **Minor/major:** run `make bump-version BUMP=minor` (or `major`), commit `packaging/Info.plist`, then merge to `main`.
3. CI skips release on commits whose message starts with `chore: bump version`.
4. Releases are signed with a **self-signed certificate** (ad-hoc when the secrets are missing) — no Apple Developer ID or notarization.
5. `HOMEBREW_TAP_TOKEN` secret updates the separate `homebrew-tap` repo.

## Git and PR guidelines

- **Do not commit** unless explicitly asked.
- **Do not push** unless explicitly asked.
- Keep changes focused; avoid drive-by refactors.
- Do not commit `.build/`, `dist/`, `.DS_Store`, or release zips.
- Do not commit secrets (`HOMEBREW_TAP_TOKEN`, signing certificates, `.env`).
- Prefer conventional commit prefixes: `feat:`, `fix:`, `chore:`, `docs:`.
- Version bumps: `chore: bump version to X.Y.Z`.

### Before finishing a change

1. Run `make build` for compile errors.
2. Run `make test` when MacMouseCore logic changed.
3. For UI changes, note that manual verification requires `make app`.

## Security and privacy

- Keep user data **local** unless the product explicitly needs network access.
- Do not commit secrets or tokens.
- CI uses repository secrets only for automated Homebrew tap updates.

## Human-facing docs

- **README.md** — install, usage, release overview (keep in sync when changing user-visible behavior).
- **AGENTS.md** (this file) — agent-oriented bootstrap, architecture, and conventions.

When user-visible behavior changes, update README.md. When agent-relevant workflows change, update this file.
