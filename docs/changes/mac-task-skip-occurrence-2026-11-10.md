# TASK-MAC-SKIP-001 — Skip the current recurrence from Mac Tasks

The local Tasks and Calendar parity goal authorizes this change. TickTick documents skipping from the right-click menu of a recurring Desktop task. Taskovsky adds Skip this occurrence… to the task-row context menu and task-detail More actions. [TickTick Tasks FAQ](https://help.ticktick.com/articles/7055792921664028672).

The command appears for an open recurring task whose series can advance under the shared [schedule rules](calendar-skip-occurrence-2026-11-10.md). The confirmation names the task. Cancel or Escape dismisses it. Skip advances the saved series and offers Undo in the existing five-second task toast. The store rechecks the task status and the exact schedule captured by the confirmation. Undo uses the same schedule guard as Calendar. A failed save leaves the schedule intact and reports the failure.

The same task and its applicable reminder and duration move to the next legal date. No successor task is created. Terminal series, archived and trashed tasks, notes and ineligible recurrence states lack the action. The named confirmation and detail shortcut are Taskovsky choices.

This change refines [BUS-013 and BUS-014](../spec/business.md#bus-013) and the [Mac Tasks interface](../spec/ui-ux.md). The existing workspace schema and Calendar workflow are reused. Verify native menu availability, Cancel, confirmed advancement, Undo, relaunch and terminal eligibility against a disposable workspace. [Verification](../spec/verification.md#mac-task-skip-occurrence).
