# D08 Duration cards and nested transactions

Status: Implemented; exact-head CI pending. Base `0dac439`. User-directed mobile broad similarity before final pixel polish.

## Reference and bounded scope

Private live inspection turn `01a1e1f2-ae27-7b43-9347-9a37e42351b7` observed timed Date/Time cards, duration caption, All Day toggle and all-day Start/End date cards. Date popup has calendar and Cancel/Done; all-day endpoints share calendar with Start/End tabs. Time offers a timeline with Advanced endpoint wheels. Original reference task was restored and outer Cancel used; personal screenshots withheld.

This slice implements cards and real transactional endpoint/calendar editors. Time uses endpoint wheels directly, an explicit partial approximation of reference Advanced: no unverified timeline handles, Normal mode or floating-time policy is fabricated. Existing Time Zone route remains available, including all-day schedules; reference hides its all-day caption but removing zone editing would lose existing functionality. Existing conversion defaults remain Taskovsky policy, not claimed TickTick equivalents.

## Contract

- Timed Date card displays the range end/due day, with explicit “End date · move whole range” caption. Its nested calendar calls existing `chooseDay`, preserving the range span rather than silently editing only one endpoint.
- Timed Time card shows actual start/end wall time and elapsed duration. Nested Start/End tabs choose an endpoint; wheels call existing `setStart`/`setEnd` only on actual edits.
- All-day ranges retain a separate “Move duration to another date” action using the same staged whole-range calendar; independent endpoints do not replace moving the entire span.
- All Day inversely calls existing `setTime`. Existing midnight normalization and 09:00/one-hour conversion policy unchanged. Start/End cards show actual day and open the corresponding selected calendar tab.
- Each presentation captures an exact value copy of the current outer `TaskScheduleEdit`. Opening/tab switching makes no setters. Cancel/outside dismissal discards; nested Done assigns only a valid range with known zone. Popover is modal on iPhone, preventing parent edits while its snapshot is open. Outer revision guards, Cancel, reconciliation and save-error behavior unchanged.
- Range end remains due. Seconds and non-device zones are preserved on no-op. Invalid inversion is shown, not silently clamped; nested Done disabled until corrected. Existing manual/default/end reminders and recurrence fields remain in the copied draft.
- No workspace/settings writes until existing outer Done. No changes to domain schedule mutators, Date-mode time popup, reminders or recurrence editor.

## Verification gates

Source `2fef8e9` independently rereviewed and approved. Full suite: 882 XCTest plus 38 Swift tests passed; release build and iPhone compilation passed. Corrected native run: seven tests passed, zero failures/skips/runtime warnings, process exit 0, complete `DurationCardsCorrected.xcresult` summary parsed. Simulator released after completion. Exact-head hosted CI remains required.

Initial run had five passes/two failures: test tap selected the All Day container rather than its trailing switch, and outside-dismiss target fell inside the popup. Corrected tests assert switch value and actual backdrop dismissal without weakening state checks. Independent review also caught the removed all-day whole-range move route; restored before final native pass. Exact Nov 9–10 to Nov 11–12 movement verifies both bounds, not just a date fragment.

Final cases cover original Date/Duration and Date Time popup regression; timed whole-range move with outer Cancel; all-day endpoint cancel and whole-range move; real start/end edits with save/relaunch; invalid range disabled until correction; nested Cancel/outside dismissal; nonzero seconds and non-device-zone no-op save/relaunch with manual/end reminders preserved.

Actual unmodified neutral screenshots inspected for readable layout and privacy: [timed cards](../assets/mobile-parity/2026-11-16/d08-duration-timed.png), [all-day cards](../assets/mobile-parity/2026-11-16/d08-duration-all-day.png). Reference-specific timeline/relative date captions, floating-time policy and final calibrated spacing remain explicitly unverified or deferred, not a pixel-perfect claim.

## Management integration

Merged current main `ec88bcf` at `c573731` without conflicts. Independent actual integration review confirmed D08 source/native bodies unchanged, management tests and both manifests/receipts/tracker rows preserved; no extra native rerun required from the separate management change. Integrated validation completed exit 0: 899 XCTest plus 38 Swift tests, release build and iPhone build-for-testing passed. Original seven-test native receipt remains applicable to unchanged D08 source. Refreshed exact-head hosted CI is still required before merge.
