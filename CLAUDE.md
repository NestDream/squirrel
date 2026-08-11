# CLAUDE.md

Orientation for Claude Code working in this repository. This is a fork of [rime/squirrel](https://github.com/rime/squirrel) — the macOS frontend (input method) for the Rime Input Method Engine, written in Swift 6 against InputMethodKit.

## What this project is

Squirrel (鼠鬚管) is a macOS IME app bundle. It loads librime via a C bridging header, drives an `IMKServer`, and renders a candidate panel + (in this fork) a cursor-side input-mode indicator. macOS 13.0+ only.

## Fork relationship

- `origin` → `https://github.com/NestDream/squirrel.git` (this fork — push our changes here)
- `upstream` → `https://github.com/rime/squirrel.git` (rime/squirrel — pull updates from here)

Our fork diverges from upstream in two places: the **cursor input indicator** feature (see [docs/specs/cursor-input-indicator/](docs/specs/cursor-input-indicator/)), and the **Shift-switch behavior** menu picker ([sources/ShiftSwitchBehavior.swift](sources/ShiftSwitchBehavior.swift)).

## Repo layout

| Path | What's there |
|---|---|
| [sources/](sources/) | All Swift source. App entry point is [Main.swift](sources/Main.swift). |
| [Tests/](Tests/) | Swift Package tests for the fork's own features (run via `swift test`). |
| [Squirrel.xcodeproj/](Squirrel.xcodeproj/) | The real build target — produces `Squirrel.app`. |
| [Package.swift](Package.swift) | Swift Package for unit-testing the fork's additions only. **Not** the app build. |
| [data/squirrel.yaml](data/squirrel.yaml) | Default config shipped with the app. |
| [docs/specs/](docs/specs/) | Design docs for the indicator feature (requirements / design / tasks). |
| [librime/](librime/) | Submodule — Rime engine C++ source. |
| [Sparkle/](Sparkle/) | Submodule — auto-update framework. |
| [plum/](plum/) | Submodule — Rime config/schema package manager. |
| [Frameworks/](Frameworks/), [bin/](bin/), [lib/](lib/) | Build artifacts (gitignored). Populated by `make deps`. |
| [Makefile](Makefile) | Top-level orchestration: `make deps`, `make release`, `make install-release`. |
| [INSTALL.md](INSTALL.md) | Full build-from-source instructions. |

## Source files at a glance

| File | Role |
|---|---|
| [sources/Main.swift](sources/Main.swift) | `@main` entry. CLI flag handling (`--install`, `--reload`, …) and `IMKServer` setup. |
| [sources/SquirrelApplicationDelegate.swift](sources/SquirrelApplicationDelegate.swift) | `NSApplicationDelegate`. Owns `panel`, `indicator`, `config`. Hosts the C `notificationHandler` callback that Rime invokes on option changes. |
| [sources/SquirrelInputController.swift](sources/SquirrelInputController.swift) | `IMKInputController` subclass. Per-session key handling, `rimeUpdate()` syncs Rime context → panel/indicator. |
| [sources/SquirrelPanel.swift](sources/SquirrelPanel.swift) | Floating candidate window (`NSPanel`). |
| [sources/SquirrelView.swift](sources/SquirrelView.swift) | Custom `NSView` that renders the candidate panel contents. |
| [sources/SquirrelTheme.swift](sources/SquirrelTheme.swift) | Theme/color/font model loaded from `squirrel.yaml`. |
| [sources/SquirrelConfig.swift](sources/SquirrelConfig.swift) | Thin wrapper over Rime's config API; `getBool` / `getString` / `getColor`. |
| [sources/SquirrelIndicator.swift](sources/SquirrelIndicator.swift) | Fork-only: small floating panel near cursor showing current `ascii_mode` ("中"/"A"). |
| [sources/ShiftSwitchBehavior.swift](sources/ShiftSwitchBehavior.swift) | Fork-only: reads/writes `ascii_composer/switch_key/Shift_L` in `~/Library/Rime/default.custom.yaml` for the menu picker. Pure text editing, no YAML round-trip. |
| [sources/InputSource.swift](sources/InputSource.swift) | Registers/enables/selects the input source via `TIS*` APIs. |
| [sources/MacOSKeyCodes.swift](sources/MacOSKeyCodes.swift) | Translates AppKit key events to Rime key codes. |
| [sources/BridgingFunctions.swift](sources/BridgingFunctions.swift) | Helpers to call the C Rime API from Swift. |
| [sources/Squirrel-Bridging-Header.h](sources/Squirrel-Bridging-Header.h) | Imports `rime_api_stdbool.h` and `key_table.h`. |

## Building

The Xcode project is the real build. The Makefile orchestrates the dep chain (librime → boost → opencc → plum data → Sparkle.framework) before invoking `xcodebuild`. From `INSTALL.md`:

```sh
# First-time setup: build C++ deps (slow — librime, boost, opencc, plum, sparkle)
make deps

# Or skip building librime from source by downloading the prebuilt:
bash ./action-install.sh

# Build the app:
make           # release
make debug

# Install to /Library/Input Methods/Squirrel.app:
make install-release
```

Required env: `BOOST_ROOT` must point at a Boost source tree before `make deps`. `MACOSX_DEPLOYMENT_TARGET=13.0` minimum.

## Testing

The `Package.swift` is **only for unit-testing the fork's own additions** — it isn't the app build. It compiles a minimal `SquirrelCore` target containing just [sources/SquirrelIndicator.swift](sources/SquirrelIndicator.swift) and [sources/ShiftSwitchBehavior.swift](sources/ShiftSwitchBehavior.swift) so the tests in [Tests/](Tests/) can exercise them without pulling in librime.

```sh
swift test
```

If you change either of those two files you should run `swift test`. If you change anything else, test via Xcode (`xcodebuild -scheme Squirrel build`) or by building + installing and exercising the IME live — there's no other automated test harness.

Adding a new source file means registering it in **both** [Package.swift](Package.swift) (`sources:` list, if it should be tested) and [Squirrel.xcodeproj/project.pbxproj](Squirrel.xcodeproj/project.pbxproj) (build file, file reference, group, sources phase) — otherwise it won't compile into the app.

## Style & lint

- [.swiftlint.yml](.swiftlint.yml) — `force_cast`, `force_try`, `todo` disabled. Line length ≤ 200, file length ≤ 800 (warn) / 1200 (err). 2-space indent (per existing files).
- [.periphery.yml](.periphery.yml) — unused-code analyzer config.
- Follow existing file conventions: `final class`, no `self.` unless required, top-of-file `//` header in the existing format. Keep the bilingual (中文 / English) tone in user-facing strings (`CHANGELOG.md`, `README.md`, `data/squirrel.yaml` comments).

## Conventions for changes

- **Commit messages**: Conventional Commits style (`feat:`, `fix:`, `docs:`, `chore:`, `style:`, `ci:`, `feat(ui):`). Recent history shows both English and Chinese; either is fine, match the change's audience. Tag major releases via `chore(release): X.Y.Z :tada:`.
- **CHANGELOG.md**: bilingual sections — `主要功能更新 | Major Updates`, `Bug 修復 | Bug Fixes`, `構建 | Build`, `雜項 | Miscellaneous`. Add a note for any user-visible change.
- **Pulling from upstream**: this fork's structural divergence from `rime/squirrel` is limited to the indicator feature and the Shift-switch menu picker — most upstream changes won't conflict. When merging, prefer `git merge upstream/master` (preserves upstream history) over rebase.
- **Submodules**: `librime`, `Sparkle`, `plum`. Use `git submodule update --init --recursive` after fresh clones.

## Indicator feature — quick map

The fork adds a "show input mode near cursor" indicator. End-to-end, it touches:

- [sources/SquirrelIndicator.swift](sources/SquirrelIndicator.swift) — the `NSPanel` itself.
- [SquirrelApplicationDelegate.swift:applicationWillFinishLaunching](sources/SquirrelApplicationDelegate.swift) — instantiates it.
- [SquirrelApplicationDelegate.swift:loadSettings](sources/SquirrelApplicationDelegate.swift) — reads `style/show_input_indicator`, `style/indicator_chinese_color`, `style/indicator_ascii_color`, `style/indicator_follow_cursor` from `squirrel.yaml`.
- The C `notificationHandler` at the bottom of `SquirrelApplicationDelegate.swift` — updates the indicator on `ascii_mode` changes.
- [SquirrelInputController.swift](sources/SquirrelInputController.swift) — `activateServer` / `deactivateServer` / `rimeUpdate` / `showPanel` show/hide/move it.

Spec/design docs: [docs/specs/cursor-input-indicator/](docs/specs/cursor-input-indicator/).

## Things to know

- The Rime engine runs in-process via librime; it talks back to Squirrel through the C `notificationHandler` callback registered in `SquirrelApplicationDelegate.setupRime()`.
- macOS IMEs are background-only apps (`accessory` activation policy). `NSApp` runs but there is no main window — only `NSPanel` floating windows.
- User config lives at `~/Library/Rime/`. After editing `squirrel.custom.yaml`, the user must trigger "Redeploy" (or `Squirrel --reload`) for changes to take effect.
- License: GPL-3.0 (see [LICENSE.txt](LICENSE.txt)).
