# Mobile Time popup (D09)

## Identity and decision

- Change ID and title: D09 Time popup — Date-mode compact Time editor.
- Status: Locally verified; integration checks and hosted CI pending.
- Owner or requesting instruction: iPhone D09 parity task, November 15, 2026.
- Base commit and affected platforms: isolated checkout at `65ca076`; iPhone only (`Mobile/App/PhoneScheduleSheet.swift`, `Mobile/UITests/ReadOnlyNavigationTests.swift`, `Tests/TaskovskyDomainTests/ScheduleTimePopupTests.swift`).
- Related business, UI, component, parity and deviation IDs: BUS-011, BUS-012, BUS-014; IOS-007; D09 row of `docs/ticktick-spec/mobile-surface-inventory-2026-11-14.md`; TT-012.

## Outcome and scope

Date-mode schedules (no duration window) now stage time through a Time summary
button that opens a compact wheel popover: hour/minute wheels with the staged
time zone shown below, a Done control that closes the popup while keeping the
staged time, and an inline Remove time control in the sheet. Opening the popup
on an all-day draft stages a time through the existing `setTime(true)` default
(09:00 wall time); popup close retains it; outer Cancel/Done keep their existing
transaction semantics (discard/save).

Explicitly unchanged: the Duration toggle and Start/End endpoint editing and
conversions, reminders/repeat editors, revision guards, unknown-zone warnings,
interruption/Cancel behavior, and data-safety rules. No guessed TickTick
reference default time is introduced. No macOS code changes.

## Current behavior and intended delta

Before: Date mode showed a `Toggle("Time")` (`scheduleTime` switch) plus an
inline `DatePicker("Due time")` with no identifier. After: Date mode shows a
`Button` (`scheduleTime`, value `None` or the staged time) that stages a time
if needed and presents `PhoneScheduleTimePopover`; when a time is staged, a
destructive `Remove time` button (`scheduleTimeRemove`) clears it via
`setTime(false)`. The popover contains a `.wheel` hour-and-minute picker
(`scheduleTimeWheels`, bound to `edit.schedule.effectiveDue` via `setEnd`),
a time-zone caption row below (`scheduleTimeZone`, staged value or
`Device time zone`), and a Done button (`scheduleTimePopoverDone`) that only
dismisses. The existing Time Zone section (`scheduleZone`) remains the single
zone-editing route, deliberately, to avoid stacked sheet-over-popover
presentations. Duration mode keeps the exact previous Toggle/Start/End layout
and identifiers.

Reference uncertainty: D09 confirms wheels with time zone below, staged time on
open, retained value on popup close, inline remove, and outer Cancel discard.
It does not establish whether TickTick edits the zone from inside the popup,
the exact wheel defaults for a previously untimed task, or the reference
typography/geometry — none of these are claimed here.

## Data and component contract

All staging goes through `TaskScheduleEdit.setTime/setEnd/setZone`; no new
persistence, schema, reminder, recurrence, or zone-migration semantics.
`applying(to:)` still decides save/no-write; untouched reopen still returns the
identical task. Duration `setDuration/setStart/setEnd` paths are untouched.

## UI and UX contract

| Aspect | Detail |
| --- | --- |
| Layout | Date-mode Time row is a summary button; popup shows wheels, divider, zone caption, Done. Duration mode layout unchanged. Zone section stays below the Date/Duration section. |
| Interaction | Tap Time stages (09:00 if untimed) and opens the popup (`.popover` with `.presentationCompactAdaptation(.popover)`). Done or outside dismissal keeps the staged value. Remove time clears inline. Outer Cancel discards; Done saves. |
| State | `None` value with no remove control when untimed; formatted time value plus remove control when timed. Existing invalid-duration and unknown-zone messaging unchanged. |
| Accessibility | `scheduleTime` button exposes value `None`/time; wheels, zone caption, Done, and remove controls have identifiers and 44pt-reachable targets via standard controls. Existing VoiceOver/switch coverage preserved; no new gestures. |
| Platform difference | iPhone-only presentation change over shared staging rules. macOS editor untouched. |

## Acceptance cases

1. Open popup on an all-day date: time stages (existing 09:00 default), wheels and zone caption appear, Done closes and retains with inline remove visible.
2. Selected time saves; reopen shows the same time; inline remove plus Done restores the all-day schedule; relaunch preserves each saved state.
3. Popup close retains; outer Cancel discards both staged time and staged zone (label unchanged on reopen).
4. Zone route (`scheduleZone`) still opens, searches, and applies on a staged draft.
5. Duration tab still shows the Toggle plus Start/End range editor with existing conversion behavior.

## Verification and release

- New `ScheduleTimePopupTests` (6 cases) exercise the production staging path: open default, close-retain/Cancel-discard, save/reopen/no-write, remove, wall-clock zone change, Duration conversions.
- Updated 5 existing UI selectors from the `scheduleTime` switch to the button where Date mode is under test; Duration-mode switch assertions kept. Added `testScheduleTimePopupOpensStagesClosesAndOuterCancelDiscards` and `testScheduleTimeSaveReopenRemoveAndDurationUnchanged`; extended the skip-occurrence flow with a popup-staging helper.
- `swift test --disable-sandbox` and `./scripts/build-app.sh`: see final report.
- Initial implementation checkpoint: native Simulator tests had not run. Subsequent native results are recorded below.

## Completion record

Implementation and local native verification complete. Integration validation, independent final review and exact-head CI remain required.

## Final local verification

844 XCTest (134 workspace,55 Mac,126 domain,529 core) and38 Swift Testing passed; release build passed. Native actual wheel10:35/save/reopen/remove/Duration and outerCancel/zone staging passed2/2. Existing range-move cancellation passed in first run. Extended owned Kiritimati00:15:37 fixture passed: rendered wheel/summary/zone, outside dismissal, Done and relaunch retain exact saved epoch/time flag/zone. QA diagnostic value is empty outside that isolated case. Initial native failures exposed parent AX identifier inheritance and spoken wheel-unit/zero-padding assertions; corrected without dropping behavioral assertions. Final native results: TimePopupNative2.xcresult and TimePopupPrecision2.xcresult.

Actual neutral1170x2532 screenshot pixel-inspected: [Time popup](../assets/mobile-parity/2026-11-15/d09-time-popup.png). Native2 capture predates only the additional QA fixture, not popup source changes. Fonts/geometry/default-time equivalence to TickTick remain unverified. Exact CI and independent final review required before merge.
