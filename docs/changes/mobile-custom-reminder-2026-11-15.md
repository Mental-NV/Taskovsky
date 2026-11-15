# D11 Custom Reminder: all-day single-date draft

## Scope and evidence

The mobile reference inventory observes Custom Reminder Day/Week, offset/time wheels, an expired warning, Cancel and Add. This bounded implementation adds that structure only to all-day single-date schedule drafts. Timed and Duration flows retain the absolute reminder editor. The existing absolute editor and Add reminder route remain available.

| Element | Placement / wording | Working behavior |
| --- | --- | --- |
| Custom | Reminder options row | Opens anchored popup; not the reference centered dialog |
| Custom Reminder | Popup heading | Identifies local staged editor |
| Day / Week | Segmented row above wheels | Changes civil-day multiplier without resetting offset |
| Offset / hour / minute | Three wheels, 150 pt high | Selects 0–52 units, 00–23 hours, 00–59 minutes |
| Zone and preview | Beneath wheels | Shows actual schedule-zone computed reminder |
| Expired warning | Beneath preview | Disables Add for expired time; Add also rechecks the live model clock |
| Cancel / Add | Footer, 44 pt minimum label hit frames | Cancel discards nested edits; Add stages reminder, not a task write |

Taskovsky choices, not verified TickTick semantics: default Day/0/09:00, common maximum 52 for either unit, first occurrence of a repeated wall time. Nonexistent DST times are rejected, never silently clamped. Computation subtracts calendar days in the schedule zone, not fixed elapsed seconds. Production Add uses the current model clock; isolated QA uses its deterministic fixture clock. The warning refreshes on interaction, not a continuously running timer; Add still refuses a newly expired date.

Adding custom reminders freezes the currently staged automatic dates (including staged date/time-zone changes), adds without duplicates and sorts. It does not discard automatic reminders. Outer Cancel discards all staged changes. Existing applying/revision validation owns persistence. No conversion, recurrence or default-reminder policy is changed.

## Verification

- Preintegration package checks: 849 XCTest + 38 Swift tests passed; release passed. After integrating main fe9af52, 851 XCTest + 38 Swift tests, release and iPhone build-for-testing passed.
- Domain tests cover DST gaps/repeats, leap boundary, schedule-zone day/week offsets, limits and unit switching, staged date/zone automatic-to-manual migration and duplicate prevention.
- Final native two-case run passed: actual Week→Day switching and nondefault offset1/hour10/minute35 wheels, nested/outer Cancel, exact computed preview versus saved/reopened reminder after relaunch and expired disabled state. Native test/build completed successfully.
- Independent final source/test/doc review clean at e710ee6. Exact-head hosted CI pending. No pixel-perfect acceptance claim.

## Screenshot

[Neutral owned-Simulator capture](../assets/mobile-parity/2026-11-15/d11-custom-reminder.png), captured from final reviewed-fix source with Day/1/10:35 controls. Pixel-inspected, no personal TickTick content. Popup placement differs from the reference; final polish remains open.
