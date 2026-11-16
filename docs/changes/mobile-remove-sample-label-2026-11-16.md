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
- Simulator/UI tests: NOT RUN here by explicit instruction — no Simulator or UI
  session was started. Awaiting parent-coordinated handoff.
- `swift test --disable-sandbox`, `./scripts/build-app.sh`, and iPhone
  compile results: recorded at commit time (see commit message / ledger entry).
- No push/PR/merge performed; no personal data or screenshots introduced.
