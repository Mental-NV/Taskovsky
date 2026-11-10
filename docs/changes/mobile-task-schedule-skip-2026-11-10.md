# TASK-MOBILE-SKIP-001 — Skip the current recurrence from iPhone Tasks

TickTick documents swiping left on a recurring task and choosing Skip in the date popup. In Taskovsky, swipe left and tap Schedule, or open Schedule in task detail. The Repeat section offers Skip this occurrence for an open recurring task with a valid next occurrence. [TickTick Tasks FAQ](https://help.ticktick.com/articles/7055792921664028672).

Skip this occurrence stages the action. Done advances the saved series through the shared [recurrence rules](calendar-skip-occurrence-2026-11-10.md). Keep editing restores the unsaved date, reminder and repeat draft. Cancel discards the draft and staged skip. A failed write leaves the staged action available for retry or cancellation. A stale revision asks the user to reopen Schedule.

The same task moves forward with its applicable duration and reminders. A terminal series, a completed or abandoned task, and a series that already has a successor lack the action. Undo in the Tasks list or detail restores the previous schedule when that task still matches the saved change. Tasks and Calendar retain their respective in-session schedule notices and Undo targets.

The existing Schedule sheet, the separate confirmation step and the placement in Repeat are Taskovsky choices. The action uses the local workspace and shared transaction rules.

[Verification](../spec/verification.md#mobile-task-schedule-skip).
