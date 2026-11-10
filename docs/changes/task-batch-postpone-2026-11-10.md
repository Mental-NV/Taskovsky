# TASK-BATCH-002 — Postpone timed tasks by one hour

[Verification](../spec/verification.md#task-batch-postpone).

TickTick documents selecting tasks in a list or Calendar and using Postpone on Windows and web. Its changelog records a one-hour action. [Calendar View Options](https://help.ticktick.com/articles/7055782085826445312) and [TickTick changelog](https://ticktick.com/public/changelog/).

- On Mac and iPhone, Tasks → Select Tasks offers Postpone 1 Hour when every selected item is an open timed task. Calendar → Postpone Tasks opens the same selector directly for that action. Its candidates follow the saved list, Inbox and tag sources across dates. Each candidate shows its due time in the Calendar display zone. Select the tasks, review, then Apply.
- A timed deadline moves by 3,600 elapsed seconds. A timed range moves both endpoints by the same amount. Manual reminders move by the same amount, and automatic reminders follow the workspace's existing schedule defaults. A repeating task moves its current occurrence and retains its original future cadence.
- All-day and undated items, notes, completed and Won't Do items, archived and trashed items, incompatible schedules and repeating records with a persisted successor are ineligible. A mixed selection offers the commands common to its members. Postponing a parent affects its own schedule. Select a child separately to move it too.
- The existing batch validation and one-write policy apply. Cancel discards the staged change. The existing current-occurrence restore command remains available for an eligible repeating task. The batch itself has no dedicated Undo.
- The fixed elapsed interval, eligibility, recurrence treatment and staged native selectors are Taskovsky choices. The documented reference platforms for Postpone are Windows and web.
