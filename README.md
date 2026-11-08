# Taskovsky

Taskovsky is a local macOS task and notes application inspired by TickTick's task workspace. It uses SwiftUI and AppKit, with a Swift package core and no third-party dependencies. The current package targets macOS 14 or later, uses Swift tools 6, and compiles in Swift 5 language mode. It does not yet contain an iPhone application.

## Build and run

```sh
./scripts/build-app.sh
open build/Taskovsky.app
```

The build script assembles and locally signs the app; this is not a notarized distribution build. For development, use `swift run --disable-sandbox Taskovsky`. Run the existing tests on a suitable macOS environment with `swift test --disable-sandbox`.

## Specifications and development

Start with the [documentation index](docs/README.md).

- [Business behavior](docs/spec/business.md): code-derived task, scheduling, organization, search, storage and lifecycle contracts.
- [macOS UI and UX](docs/spec/ui-ux.md): fonts, colors, icons, layout, motion and interaction states.
- [TickTick feature parity](docs/parity-implementation-status.md): the dedicated implementation-progress and comparison tracker.
- [Shared engine](docs/architecture/shared-engine.md) and [component boundaries](docs/architecture/components.md): proposed reuse for macOS and iPhone, including independently developed rich editors.
- [iPhone UI proposal](docs/spec/iphone.md): native phone presentation and explicitly limited editor capabilities.
- [Spec-driven workflow](docs/spec/workflow.md), [change template](docs/spec/change-template.md) and [verification ledger](docs/spec/verification.md): how to specify, implement and verify future work.

The current specifications were reconciled against source commit `30045bac5355b793a8c155b87ffe58584cb29fb8`. They describe implementation, not a fresh runtime certification. Known code-review deviations remain visible; fixing them is a separate workstream. Future approved specifications describe a delta from this baseline, not a license to overwrite existing behavior.

## Current capabilities and limits

The macOS app includes tasks and notes, rich descriptions, embedded checklists and independent child tasks; lists, folders, nested tags and saved filters; due dates, custom recurrence, duration windows and stored reminders; list and status-board views; search, local summaries, templates, and recoverable Trash. See the business specification for precise interactions and exceptions rather than assuming every feature has full TickTick parity.

Use **⌘N** to add a task, **⇧⌘N** to add a note, **⇧⌘L** to create a list and **⌘,** for Settings. Task rows and sidebar entries expose context actions. Date editing uses a staged schedule popover. Deleting a list moves its items to Inbox; deleting a tag removes its references. Individual items can be permanently deleted from Trash after confirmation; there is no bulk Empty Trash.

Data saves locally to `~/Library/Application Support/Taskovsky/workspace.json`, with preferences in `settings.json`. The app preserves an unreadable workspace and surfaces save failures. URL-title recognition is the network feature; there is no account or server synchronization. Reminders are shown while the app is running, not delivered by an OS notification/background service.

Separate Calendar, Eisenhower Matrix, Pomodoro, Habit and Countdown modules, accounts, sync, statistics, system notifications, help and voice dictation are outside the current baseline. Archived TickTick research about those features is not an implementation request.

## Isolated visual QA

```sh
python3 scripts/seed-qa-fixture.py
open build/Taskovsky.app --args --workspace /tmp/TaskovskyQA/workspace.json
```

The fixture is disposable. `--workspace` isolates workspace/settings files and layout preferences that use `IsolatedDefaults`; see [IsolatedLaunch.swift](Sources/TaskovskyCore/IsolatedLaunch.swift). Quick-search history still uses `UserDefaults.standard` in [SearchView.swift](Sources/Taskovsky/SearchView.swift), so full preference isolation is not guaranteed. Never point destructive or experimental QA at the user's normal workspace. The fixture currently uses runtime dates and some random IDs, so it is not a deterministic screenshot baseline.

No build, test suite or native UI session was run for the documentation-only reconciliation. Previous validation reports remain [historical evidence](docs/archive/parity-implementation-history.md), not current test results.
