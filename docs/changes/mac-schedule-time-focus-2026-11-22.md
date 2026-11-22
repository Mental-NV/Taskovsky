# MAC-SCHEDULE-FOCUS-001 — Focus the Time editor on first activation

Mac Task detail Schedule, [MAC-13](../mac-parity-acceptance.md#acceptance-matrix), [TT-012](../parity-implementation-status.md#tt-012). Base `014b60c9274d2e81b56715fed38fe88f72cea4c8`.

The [dated TickTick observation](../ticktick-spec/scheduling.md#opening-and-structure) found that activating Time on an undated task selected today, seeded 00:00, focused its editor and opened a menu with half-hour choices. The guarded Taskovsky baseline used equivalent Schedule source at 964 points and in a 780-point drawer. Today and 00:00 were staged, but native focus remained on the prior Today control and an immediate numeric key did not edit the new field. The inline time control could still be adjusted separately, and outside/native Cancel left the task unscheduled.

A first SwiftUI focus request moved focus to the main window rather than the editable segment in a native 964-point test. Use the native segmented AppKit control with an explicit first-responder request after attachment. Native Return and the OK button share the same invalid-duration guard. Keep the time binding, stepper, and existing OK/Escape meaning; no changes to defaults, options, duration, time zones, storage or iPhone. The TickTick half-hour menu and exact visuals remain separate open comparison cases.

## Acceptance

- From an unscheduled neutral task, open Schedule and activate Time once in docked and compact detail. Verify Today and 00:00, then change a component by keyboard without a second click if supported.
- Escape or Cancel discards the schedule draft. An explicit OK commits only chosen date/time; no duration or unrelated metadata changes. Reopening and re-expanding Time must not change an already scheduled value merely by focusing it.
- Report native focus/keyboard evidence separately from compile and visual evidence. An accessibility element's existence alone does not prove editing focus.
