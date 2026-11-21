# Taskovsky

Taskovsky is a local Tasks and Calendar app inspired by TickTick, with a native macOS app and a separate iPhone app. Both share Swift domain logic with platform-specific UI. The [documentation index](docs/README.md) distinguishes intended behavior, TickTick evidence and verified parity.

## Build and run

```sh
./scripts/build-app.sh
open build/Taskovsky.app
```

The build script assembles and locally signs the app; this is not a notarized distribution build. For development, use `swift run --disable-sandbox Taskovsky`. Run the existing tests on a suitable macOS environment with `swift test --disable-sandbox`.

## Specifications and development

- [Desktop and iPhone parity specs](docs/README.md) · [46-state iPhone visual tracker](docs/mobile-visual-parity.md)
- [iPhone build and Simulator QA](Mobile/README.md) · [macOS CI and verification](docs/spec/ci-cd.md)

Use **⌘N** to add a task, **⇧⌘N** for a note, **⇧⌘L** for a list and **⌘,** for Settings. By default, the Mac app stores workspace and settings JSON in `~/Library/Application Support/Taskovsky/`. Cross-device sync and external Calendar integrations are outside the local pre-alpha scope.

## Isolated visual QA

```sh
python3 scripts/seed-qa-fixture.py
open build/Taskovsky.app --args --workspace /tmp/TaskovskyQA/workspace.json
```

The fixture is disposable. `--workspace` isolates workspace/settings files and layout preferences that use `IsolatedDefaults`; see [IsolatedLaunch.swift](Sources/TaskovskyCore/IsolatedLaunch.swift). Quick-search history still uses `UserDefaults.standard` in [SearchView.swift](Sources/Taskovsky/SearchView.swift), so full preference isolation is not guaranteed. Never point destructive or experimental QA at the user's normal workspace. The fixture currently uses runtime dates and some random IDs, so it is not a deterministic screenshot baseline.

Calendar-specific disposable data can be generated with [seed-calendar-qa.py](scripts/seed-calendar-qa.py). CI does not verify native gestures or visual behavior; see the [verification ledger](docs/spec/verification.md).
