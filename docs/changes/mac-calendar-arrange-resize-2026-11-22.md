# MAC-CALENDAR-ARRANGE-001 — Preserve Arrange controls during resize

Status: candidate for [MAC-16](../mac-parity-acceptance.md#acceptance-matrix), macOS only. See [TT-033](../parity-implementation-status.md#tt-033) and [UX-017](../spec/ui-ux.md#ux-017).

## Evidence and intended behavior

The [dated live TickTick observation](../ticktick-spec/calendar.md#follow-up-evidence--8-november-2026) establishes a right Arrange sidebar with List, Tag and Priority grouping, All Lists and an individual-list chooser, and two undated tasks present while a Today-scheduled control was absent. It did not establish TickTick's resize, overdue toggle lifecycle or drop behavior. No visual axis is scored.

Guarded Taskovsky on the Calendar source in `cebf043b3b01487463b97c824eee4c9f2694c269` showed the same controls and undated-versus-Today distinction. With Arrange open at 1060×700 and Priority, a specific list and Include overdue set, narrowing to 780×584 kept the panel open but reset all three controls. An unrelated-list undated task reappeared. Setting Tag, the other list and overdue on in the overlay then widening also reset all three. This is a reproducible local state loss, not evidence of TickTick's transition.

Own the three transient controls in the Calendar workspace. Both dock and overlay use those controls for the duration of one open Arrange panel. Deliberate close still resets defaults on reopen, whether done via the panel button or header menu. Keep the existing projection, calendar scope, panel geometry, drag and Schedule actions, data persistence and iPhone unchanged.

## Acceptance

- Confirm distinct scoped and unscoped undated tasks, and exclusion of a Today-scheduled control, in the native right panel.
- Leave Priority, a specific list and Include overdue set while crossing the 760-point Calendar content threshold in both directions (use measured host widths). Check control values, result membership, unchanged main Calendar state and no writes.
- Close explicitly from the panel, reopen, and verify List / All Lists / Include overdue off. Repeat from the header menu. Data and persisted settings must not change as a result of Arrange controls.
- Keep split teardown, scroll offset, native drop and reference resize/geometry claims out of this receipt.
