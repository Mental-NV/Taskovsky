# D08 Duration cards and nested transactions

Status: In implementation. Base `0dac439`. User-directed mobile broad similarity before final pixel polish.

## Reference and bounded scope

Private live inspection turn `01a1e1f2-ae27-7b43-9347-9a37e42351b7` observed timed Date/Time cards, duration caption, All Day toggle and all-day Start/End date cards. Date popup has calendar and Cancel/Done; all-day endpoints share calendar with Start/End tabs. Time offers a timeline with Advanced endpoint wheels. Original reference task was restored and outer Cancel used; personal screenshots withheld.

This slice implements cards and real transactional endpoint/calendar editors. Time uses endpoint wheels directly, an explicit partial approximation of reference Advanced: no unverified timeline handles, Normal mode or floating-time policy is fabricated. Existing Time Zone route remains available, including all-day schedules; reference hides its all-day caption but removing zone editing would lose existing functionality. Existing conversion defaults remain Taskovsky policy, not claimed TickTick equivalents.

## Contract

- Timed Date card displays the range end/due day, with explicit “End date · move whole range” caption. Its nested calendar calls existing `chooseDay`, preserving the range span rather than silently editing only one endpoint.
- Timed Time card shows actual start/end wall time and elapsed duration. Nested Start/End tabs choose an endpoint; wheels call existing `setStart`/`setEnd` only on actual edits.
- All Day inversely calls existing `setTime`. Existing midnight normalization and 09:00/one-hour conversion policy unchanged. Start/End cards show actual day and open the corresponding selected calendar tab.
- Each presentation captures an exact value copy of the current outer `TaskScheduleEdit`. Opening/tab switching makes no setters. Cancel/outside dismissal discards; nested Done assigns only a valid range with known zone. Popover is modal on iPhone, preventing parent edits while its snapshot is open. Outer revision guards, Cancel, reconciliation and save-error behavior unchanged.
- Range end remains due. Seconds and non-device zones are preserved on no-op. Invalid inversion is shown, not silently clamped; nested Done disabled until corrected. Existing manual/default/end reminders and recurrence fields remain in the copied draft.
- No workspace/settings writes until existing outer Done. No changes to domain schedule mutators, Date-mode time popup, reminders or recurrence editor.

## Verification gates

Source compile passed; final fixture/tests compile, full/release and independent source review underway. Native slot reserved by management; no native claim yet. Required cases: no-op seconds/zone/reminders save-relaunch, actual endpoint edits/cancel, whole-range move+outer Cancel, all-day endpoint tabs, and Date/Duration conversion regression. Exact-head CI and neutral inspected screenshots before merge.
