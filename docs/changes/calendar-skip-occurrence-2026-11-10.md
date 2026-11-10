# CAL-REPEAT-002 — Skip the current recurring task occurrence

The autonomous local Tasks and Calendar parity goal authorizes this Mac and iPhone follow-up. It refines [BUS-028 and BUS-029](../spec/business.md#bus-028), [UX-017](../spec/ui-ux.md#ux-017) and [TT-033](../parity-implementation-status.md#tt-033). TickTick documents skipping a current recurring task from Calendar’s date popup. [TickTick FAQ](https://help.ticktick.com/articles/7055792921664028672).

In the active recurring task’s Calendar Schedule editor, Skip this occurrence stages an advance. Save on Mac or Done on iPhone commits it. Keep editing or Cancel leaves the original schedule. The same open task moves to the next legal occurrence. Its ID, content, embedded checklist, linked children, and unrelated metadata are preserved. An existing occurrence override advances from its saved series schedule. The next duration and manual reminders follow the shared successor schedule rules. Automatic reminders follow the current settings. Guarded Calendar Undo restores the previous date, cadence, reminders and any occurrence override.

Due-based series use their existing nominal cursor. For a completion-based series, skipping treats the scheduled due time as the anchor for this one step, consistent with Calendar forecasts. The action is unavailable when there is no next legal occurrence, for read-only and forecast rows, and when a successor already exists. These are Taskovsky’s local rules. Verify the same task after save, reopen and Undo, canceled staging, a terminal series, and no unrelated file changes.

[Verification record](../spec/verification.md#calendar-skip-occurrence).
