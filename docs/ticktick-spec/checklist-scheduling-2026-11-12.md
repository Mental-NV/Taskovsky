# Embedded checklist scheduling: evidence and limits

November 12, 2026; TickTick for Mac 8.2.20 (922). Taskovsky source examined at `dc6c7ab`.

Taskovsky embedded checklist items currently store identity, title and completion only. Calendar copies their parent task's schedule. These are distinct from independently scheduled linked subtasks and rich-body checkbox paragraphs.

MacDisassembler resolved a checklist-cell reminder button and its task-detail controller callback. Focused pseudocode constructs a checklist-specific date/time/reminder entity. The [official Task Details guide](https://help.ticktick.com/articles/7055782408586526720) documents setting a check item's reminder time; its keyboard-clock instruction describes mobile interaction. Static callbacks and documentation support a capability lead, not exact Calendar placement semantics.

Two bounded Mac observations used an owned task with two embedded checklist rows, an all-day parent date and a separately available Add Subtask action. Neither attempt exposed an item date/reminder control. The available Computer Use API did not provide standalone hover, so the cell's mouse-enter behavior could not be verified. No item date was set. Placement on a different day and visibility with an undated parent remain unverified; failure to expose the control is not evidence that the feature is absent. The owned probe was retained, incomplete, and Calendar navigation was restored. No private screenshots or recovered code are included here.

No Taskovsky model, schedule or projection change followed this investigation. A future implementation must first establish the reference placement rule and explicitly specify compatible serialization, copy/template preservation, recurrence handling and separate Mac/iPhone controls. Notification delivery, Calendar dragging and checklist duration are not established by this observation.
