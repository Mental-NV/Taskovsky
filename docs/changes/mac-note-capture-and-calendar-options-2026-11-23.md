# Mac Note capture and Calendar options verification

These are bounded checks in a signed Taskovsky build on macOS. The startup and resize guard isolated the synthetic workspace and settings; it did not change the paths under test. This is not a fresh TickTick comparison.

## MAC-03 Note capture

- On the [#196](https://github.com/Mental-NV/Taskovsky/pull/196) product tree, one Return in a named Note List's own **Add note** field created exactly one Note in that list. The field cleared and the note opened. It reopened after navigating away and back, with no date, time, duration, zone, reminder, or recurrence. No unrelated records changed.
- [#197](https://github.com/Mental-NV/Taskovsky/pull/197) corrected the empty Note List wording at 1060×700 and 382×584. Ordinary Task List wording stayed unchanged at both widths; Today stayed unchanged at 1060×700. The Notes smart list was not exposed in this fixture.
- On the #197 product tree at 1060×700, Shift+Return from **Add note** expanded and focused Description. Escape from Description kept both draft fields, the expanded state and Description focus. After a pointer click back into the title, Escape also retained the draft, expansion and title focus. Neither Escape saved anything.
- [TickTick's desktop guide](https://help.ticktick.com/articles/7055780476358754304) documents creating a note with Enter in the Note List's own input. It does not establish empty-state wording, Escape behavior, global Quick Entry, or exact field geometry. The failed-write/retry behavior is covered at the [store-test level](../../Tests/TaskovskyCoreTests/QuickCaptureAtomicTests.swift), not by this native check.

## MAC-20 Show Completed

On the [#196](https://github.com/Mental-NV/Taskovsky/pull/196) product tree at 1060×700 in Week, turning off **Show Completed** in Calendar View Options hid the completed synthetic card while leaving the open card visible. Escape closed View Options without rolling back the choice. The option remained off after reopen and after closing with Done and relaunching. Turning it back on restored the completed card. Workspace data was unchanged.

The [dated Calendar reference](../ticktick-spec/calendar.md) documents the option's presence. Its actual effect, persistence and Escape behavior were not rerun in TickTick. Nested Cancel was not exercised in this Taskovsky check.
