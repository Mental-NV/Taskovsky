# TASK-REMINDER-001 — Reminder at the end of a timed duration

The active local Tasks and Calendar parity objective authorizes this work on Mac and iPhone. Implemented locally. The feature branch is based on merged main `36a9e17`. Native QA also ran on the combined local branch.

In the task Schedule editor, a timed duration exposes an At the end toggle in Reminders. The reminder follows the saved end instant and can coexist with default and manual reminders. A coincident instant is displayed once. Mac shows it in the reminder badge, task detail and Reminders destination. iPhone shows the end time in the Schedule editor. Cancel discards the staged change.

The preference applies to timed durations. Saving without a timed duration clears the preference. Start-only resize keeps the end unchanged. End edits, Calendar moves and recurrence advancement derive the reminder from the new endpoint. Current-occurrence edits and Calendar Undo preserve or restore the complete schedule, including the reminder preference. Snoozing the earliest displayed reminder replaces that instant with the existing manual snooze behavior. Dismiss all also clears the end reminder.

Legacy schedules keep their existing reminder dates. Only a task with the new preference, or a saved occurrence baseline containing it, requires the protected task collection for this feature. The saved end is the source for the reminder instant. This change covers local task data and presentation. Notification delivery is separately deferred under the [parity boundary](../parity-implementation-status.md#calendar-integrations-deliberately-deferred--8-november-2026).

TickTick documents selecting At the end in Reminders after setting a duration. Timed eligibility, duplicate handling and using the existing schedule snapshot are Taskovsky choices. [TickTick reminder guide](https://help.ticktick.com/articles/7055782395743567872).

Verify staged changes, simultaneous reminders, Calendar move/resize and Undo, recurrence, reload, legacy compatibility, and the Mac and iPhone editor flows. [Business rules](../spec/business.md#bus-014) · [Mac UI](../spec/ui-ux.md) · [iPhone UI](../spec/iphone.md) · [Parity](../parity-implementation-status.md#tt-015).

[Mac and iPhone verification](../spec/verification.md#task-duration-end-reminders).
