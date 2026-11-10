# Taskovsky iPhone development preview

This partial local implementation stores JSON in its own Application Support container. Normal Debug/Release launches start empty. Existing known-format tasks support title and plain-description edits; styled descriptions are protected. Unknown/unsupported workspace data blocks rewriting. Add creates tasks/notes with list/Inbox, date/time, priority, existing tags and saved templates. Task rows and detail support completion, reopening, Won’t Do, pinning, list moves, Trash and restoration. Delete Forever requires a named confirmation for one trashed task. Existing-task metadata and organization editors remain open.

The target consumes `TaskovskyDomain` and `TaskovskyWorkspace`, not the macOS `TaskovskyCore` facade. Explicit Done saves one owned field after revision/compatibility checks. Dirty Cancel offers Discard/Keep Editing; unchanged Done preserves workspace bytes. A separate exact-text scratch draft saves after 250 ms and on background opportunities. Relaunch offers Resume/Discard without submitting. A force kill before an acknowledged scratch write can lose the newest characters. Unknown scratch data is kept and blocks replacement; stale edits retain their text without rebasing.

Capture uses the shared Mac creation policy. It previews the destination and schedule, lets users ignore recognized date/tag suggestions, and preserves template rich text, checklist, recurrence and duration. An acknowledged prepared draft is stored separately before writing. Retry checks the same stable ID; a confirmed failure retains editable input, and an uncertain result retains the submitted payload. Recovery never submits by itself. Calendar Add uses the focused day, with all-day entries reachable in hourly views and Month overflow linked to Day.

The Mac store and phone repository share lifecycle and recurrence rules. Completion and Trash offer Undo for the revision that saved the action. Reopening after relaunch uses the saved cascade ledger and retains recurrence successors. Archived tasks can move to Inbox or an active list.

Tasks and Calendar share a detail Schedule sheet. Date, time, duration, task zone, manual or default reminders, and simple or custom recurrence all stage until Done. Cancel or dismissal leaves the task file unchanged. Remove schedule also waits for Done. Untouched saves preserve the original schedule bytes, including precise times and rolled recurrence positions.

Files request iOS protection until first unlock and retain ordinary Application Support backup eligibility under device settings. No backup/restore guarantee, sync, import, account or notification permission flow is provided. Bootstrap preserves existing, partial, unreadable and orphan-staged files; no repair/overwrite UI exists. The repository is single-process, with no shared live files or multi-file transaction.

Build with installed Xcode:

```sh
xcodebuild -project Mobile/TaskovskyMobile.xcodeproj \
  -scheme TaskovskyMobile -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TaskovskyMobileBuild CODE_SIGNING_ALLOWED=NO build
```

For samples, add **Debug-only** launch arguments `--qa-session <fresh UUID>`. This selects `TaskovskyMobile/QA/<UUID>` inside the app container and loads bundled [Mac-written neutral fixtures](Fixtures/README.md), never desktop data. Relaunching with the same UUID preserves that QA session. Invalid QA/path arguments fail closed; Release refuses QA arguments. Fault cases `--qa-case save-failure|stale-save|unknown-workspace|unknown-draft|capture-empty|capture-template|capture-after-write|lifecycle` also require a valid QA UUID. They are test fixtures, not user-facing settings.

Choose an installed iPhone simulator for tests. The evidence run uses a separately created **Taskovsky QA iPhone 13 Pro**, iOS 26.3.1 (23D8133). Replace the destination if unavailable:

```sh
xcodebuild -project Mobile/TaskovskyMobile.xcodeproj \
  -scheme TaskovskyMobile \
  -destination 'platform=iOS Simulator,name=Taskovsky QA iPhone 13 Pro' \
  -derivedDataPath /tmp/TaskovskyMobileBuild \
  -resultBundlePath /tmp/TaskovskyMobileTests.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  CODE_SIGNING_ALLOWED=NO test
```

The scheme currently runs 8 shared-domain tests, 45 workspace tests and 35 native UI tests. Each UI case owns a fresh QA UUID, retained as a result attachment; relaunch tests reuse it. The read-only audit in `scripts/verify-mobile-qa-roundtrip.py --capture --lifecycle --schedule` checks the saved files against their Mac-written baseline, then invokes the explicit-path Mac fixture helper to reload known data without writes. See [exact evidence and limits](../docs/spec/verification.md#mobile-task-scheduling). Full Mac tests/build are separate checks.

The target compiles for iOS 17; only the installed iOS 26.3.1 runtime was exercised. iOS 17 runtime, physical-device/signing/notification checks, IME/VoiceOver/Dynamic Type/dark/rotation/performance and full rich rendering remain open. All seven Calendar modes, Work/All source reset, Calendar Add visibility and Month overflow have native coverage; advanced display/Arrange/gestures and reference visual matching do not. Dirty swipe dismissal is blocked with explicit Cancel available; no swipe-attempt confirmation callback is implemented. No inert controls for missing workflows are included.
