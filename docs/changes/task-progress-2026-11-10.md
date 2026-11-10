# TASK-PROGRESS-001 — Local task progress

Status: implemented and verified on the isolated Mac and iPhone line. [Verification](../spec/verification.md#task-progress).

The [TickTick Task Details guide](https://help.ticktick.com/articles/7055782408586526720) describes an editable percentage for tasks and automatic progress based on checked items. It places the desktop control below the date and documents long-press access on mobile. Exact range steps, rounding, storage and lifecycle interactions were not observed in the installed reference.

- A task without embedded checklist items can save a whole-number percentage from 0 through 100. Its default is 0. Setting 0 clears the stored value.
- When a checklist is present, display the checked share rounded down and make the percentage read-only. The stored manual percentage resurfaces if the checklist is removed. Linked subtasks and formatted body markers retain their separate behavior.
- Progress measures the task without changing completion, Won't Do, schedule, reminders or linked tasks. A new recurrence starts with zero manual progress and the existing unchecked checklist behavior. A schedule move or skip keeps the same task's progress. Reopening restores the existing recorded value. Completed, abandoned, archived and deleted tasks can show their recorded progress. Manual edits require an active editable task.
- Mac places the progress control below the schedule header. iPhone exposes the percentage below the schedule row and offers Set Progress on the task checkbox's long-press menu. Both edit a local draft with a slider, one-point stepper and explicit Cancel and Done. Keyboard and accessibility actions change the draft. Saving updates only progress and the modification timestamp. A stale progress draft is refused. Other desktop edits retain the current progress even if their draft predates it.
- Store a nonzero manual percentage in an optional task field. Existing workspaces retain their encoding until a value is written. An existing protected task-collection envelope with a new format prevents older builds from discarding progress. New readers validate the range. When the last manual percentage is cleared, the existing format-selection rules apply again.

Acceptance includes a legacy file, stale and failed saves, a percentage of 100 on an open task, automatic checklist progress, reset of recurring successors, exact other fields, a cold relaunch, and both platforms' Cancel and Done. External integrations, independent checklist scheduling and progress reporting in Summary are outside this change.
