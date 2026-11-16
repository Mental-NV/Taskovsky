# D10 all-day Reminder presets

## Contract and evidence

The November 16 bounded live TickTick audit observed independently selectable On the day, 1 day early, 2 days early, 3 days early and 1 week early presets at09:00, a None action clearing selection, selected blue rows/trailing checks, and a menu remaining open across choices. The original reference state was restored. Personal reference captures are not published.

This slice adds those real choices to Taskovsky's existing Reminder page for **all-day single-date schedules only**, before Custom. It retains default reminders and the existing absolute-date editor below them. The page remains open after each selection; the outer Schedule Done/Cancel and revision guards still own persistence. The reference anchored popup placement and timed/duration/constant reminder forms are not matched or certified by this slice.

## Behavior and safety

- Presets are calculated at09:00 in the staged schedule calendar/time zone using civil-day offsets0/1/2/3/7, not elapsed24-hour subtraction. Existing strict local-time resolution rejects a nonexistent candidate, disabling only its row; no invented fallback time.
- Selection compares exact absolute timestamps in the effective staged automatic/manual reminder dates. Opening the page does not mutate or normalize a draft.
- Explicit preset toggle materializes **current staged** default dates first, then adds/removes only that timestamp; unrelated custom dates are retained. The result is sorted and deduplicated. No alias to a single default setting.
- None explicitly disables automatic reminders and clears all manual reminders and any latent at-end flag. Empty effective defaults display None selected, but tapping it deliberately manualizes the empty selection.
- Existing manual dates remain absolute when schedule date/zone changes. Presets are not stored as new relative rules and no persistence migration is introduced.
- Unknown zones, no date, timed schedules and durations are refused by the helper. Existing excluded-form behavior is unchanged.
- No future-only restriction is guessed from the reference's past-date UI; presets preserve existing manual reminder acceptance. Notification delivery/OS permissions and exact reference save/delivery policies are not claimed tested.

## Element inventory

| Order | Element | Wording and behavior |
|---|---|---|
|1|None|Clear all; selected when effective reminder set empty|
|2–6|Preset buttons|On the day / 1 day early / 2 days early / 3 days early / 1 week early; independent toggles, trailing check, selected trait,44pt row|
|7|Custom|Existing Day/Week/time popup and validation retained|
|Following|Taskovsky compatibility controls|Use default reminders, absolute dates/Add/removal remain available; not claimed present in reference menu|

## Verification

Source checkpoint `1ef478f` independently reviewed. Full920 XCTest plus38 Swift Testing cases, release packaging and iPhone test compilation passed. Initial complete native receipt `ReminderPresetsNative.xcresult` ran four tests: both Custom regressions and None/outerCancel passed; the multi-toggle/save/relaunch test passed its interactions but failed four exact-date assertions because its expected localized strings used day-first formatting while the accessibility values were month-first. The dates and09:00 times were correct. Only those expected strings were corrected; exact day/month/year/time equality is retained. Corrected test checkpoint `b108ec6` then passed the focused native rerun `ReminderPresetsFocused.xcresult`: process exit0, complete parsed receipt1/1 Passed, zero skipped/failures/runtime warnings. Together with the three untouched passing tests, all four acceptance cases are verified. The localized-string-only correction was independently reviewed; no production source changed. Refreshed exact-head hosted CI remains required before merge.

The unmodified1170×2532 neutral Simulator screenshot was inspected and is inline in the tracker. It shows all five selected blue/check rows and None unselected, with Custom/default/absolute compatibility controls below. No clipping or personal data. It documents this page, not anchored-menu/pixel equivalence.

### PR153 integration

Merge `4b04515` integrates main `cd879b6` (removal of the sample-data root label). Both screenshot manifest sets and receipts are preserved. Reminder helpers/sheet are unchanged; the two new native relaunch waits use the imported `mobileRootReady` descendant query instead of the removed label, retaining all exact stored-date assertions. Independent actual integration review passed; no additional native rerun was required solely for that readiness substitution given PR153's native marker coverage. Integrated full920 XCTest plus38 Swift Testing cases, release build and iPhone build-for-testing passed. Refreshed exact-head CI is required; the prior successful run applies only to its prior head.
