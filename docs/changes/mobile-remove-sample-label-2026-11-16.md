# Mobile root informational-label removal

## Identity and decision

- Change ID and title: mobile root `previewNotice` label removal.
- Status: Implemented, Simulator/UI verification pending (parent coordinates the native slot).
- Owner or requesting instruction: user task, November 16, 2026 — remove the whole
  mobile root header label (`Sample workspace · Local editing` / `Local workspace ·
  Early development`), ordinary local-workspace variant included.
- Base commit and affected platforms: `origin/main` at `fb42adf` (PR151 merged);
  iPhone only. No other checkouts touched; work on branch
  `codex/mobile-remove-sample-label` in `/private/tmp/TaskovskyRemoveSampleLabel`.
- Related IDs: none (no business/parity rule required the label).

## Outcome and scope

The mobile root no longer renders any informational header label. Both variants are
gone by construction: the entire conditional `Text` block (including the
`previewNotice` accessibility identifier) was deleted from
`MobileRootView.shell`, not just reworded. The QA-only
`timePrecisionEvidence` accessibility value moved unchanged onto the genuine
tab-bar container. The tab bar now carries the readiness identifier
(`mobileRootReady`) on the real, always-rendered section switcher.

Explicitly unchanged: workspace data and persistence, QA isolation
(`PhoneWorkspaceModel.isQA`, `--qa-session` fixtures, per-QA storage keys),
recovery warnings and resume flows (`Resume saved edit?`, `Resume new task?`,
protected-draft/capture notices, scratch/recovery status), and all editing,
capture, scheduling and management functionality.

## Current behavior and intended delta

Before: `Mobile/App/TaskovskyMobileApp.swift` rendered
`Text(model.isQA ? "Sample workspace · Local editing" : "Local workspace ·
Early development")` with identifier `previewNotice` whenever `model.isQA` or
the section was not Tasks, and ~104 native-test assertions waited on it as the
root-readiness marker (two of them also read its accessibility value as
time/duration precision evidence).

After: the block is deleted; `shell` (rendered only after the workspace
document loads) exposes `mobileRootReady` on the bottom tab bar. All native
readiness waits now target `app.descendants(matching: .any)["mobileRootReady"]`
— the same timeouts, no weakened assertions, no hidden text. The two
time/duration-precision persistence checks keep their original precise
assertions through that same element: they capture `mobileRootReady.value`
(the relocated QA-only evidence preserving epoch seconds, duration start,
reminders and endReminder), assert it is non-nil/non-empty with the
`Pacific/Kiritimati` fixture baseline, and assert exact equality after
relaunch. Correction (same day): an interim revision had replaced these with
formatted visible schedule times; review found that weaker (labels drop the
epoch/reminder fields) and its added `scheduleTimeZone` reads queried a
popup-only element while closed — both reverted.

## UI contract notes

- Layout: header rows close up by one caption row; no replacement element.
- Accessibility: one identifier removed (`previewNotice`), one added on visible
  navigation (`mobileRootReady`) with `.accessibilityElement(children: .contain)`
  so the child tab IDs are unaffected — the identifier does not overwrite child
  IDs by inheritance. The pre-existing QA-only `timePrecisionEvidence`
  accessibility value moved unchanged onto that container; no new visible or
  hidden text. The model property itself is untouched.

## Acceptance cases

- Root shows no `Sample workspace · Local editing` and no
  `Local workspace · Early development` text in Tasks, Calendar, or Search
  sections (new `RootLabelRemovalTests`).
- Tasks/Calendar/Search tab switching, `Open navigation`, `openCapture`,
  `calendarJumpToDate`, and `workspaceSearch` controls keep working with no
  label present (same new tests).
- Invalid-isolation launches still show the invalid-workspace notice and no
  `mobileRootReady` element.
- Time-precision and duration-precision saves still persist across relaunch
  (exact evidence equality plus non-nil/non-empty fixture baseline).

## Verification and release

- New regression: `Mobile/UITests/RootLabelRemovalTests.swift` (2 tests),
  registered in `Mobile/TaskovskyMobile.xcodeproj` (file ref
  `C1A11CE00000000000000001`, build file `C1A11CE00000000000000002`).
- Native QA (owned Simulator slot, explicitly handed over): **6/6 passed,
  0 failures** across two runs on `B263E8E7` (Taskovsky Menu QA 1114,
  iPhone 13 Pro, iOS 26.3.1), nonparallel, collect-test-diagnostics never.
  Run 1 (`label-removal.xcresult`): both `RootLabelRemovalTests` plus
  `testTimePrecisionZoneAndOutsideDismissal` and
  `testDurationCardsNoOpPreservesSecondsZoneAcrossSave` — exact evidence
  equality across relaunch verified. Run 2 (`label-removal2.xcresult`):
  strengthened `RootLabelRemovalTests` rerun — `mobileRootReady` uniqueness
  (`count == 1`) in Tasks/Calendar/Search, no label strings in any section,
  Tasks/Calendar/Search navigation plus `Open navigation`, `openCapture`,
  `calendarJumpToDate`, `workspaceSearch` all working. Only benign toolchain
  AppIntents metadata note; no test errors or failures.
- Screenshots (exported from `label-removal2.xcresult`, visually inspected,
  runner-local at `/private/tmp/TaskovskyRemoveSampleNative/screenshots/`):
  `tasks-root-no-label.png` and `calendar-root-no-label.png`, 1170x2532,
  neutral QA fixtures — header shows navigation/title/overflow only, no
  informational label in either section. Published under
  `docs/assets/mobile-parity/2026-11-16/` and linked from the
  [visual tracker](../mobile-visual-parity.md#evidence-root-label-removal).
- `swift test --disable-sandbox`: 915 XCTest + 38 Swift Testing, 0 failures.
  `./scripts/build-app.sh` + `codesign --verify --deep --strict`: pass.
  iPhone `build-ios-simulator-ci.sh`: TEST BUILD SUCCEEDED (final UI-test
  source also compiled cleanly inside the native runs).
- No push/PR/merge performed; no personal data introduced. The handed-over
  Simulator was left booted as found; no resets, no settings changes, no
  other-device contact.
