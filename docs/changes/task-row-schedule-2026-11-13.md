# Tasks row scheduling entry point

Base main `a8b491f`; isolated branch `fix/task-row-schedule-menu`.

## Evidence and delta

The [observed TickTick active task menu](../ticktick-spec/tasks.md#active-task-context-menu) contains date controls. Taskovsky currently requires a detail-panel detour despite already having a staged ScheduleEditor. Add the existing textual “Schedule…” action to active task-row context menus, anchored to that row and targeting its ID without changing detail selection. Reuse the same ScheduleEditor and `saveSchedule(updated, expected:)` conflict handling as task detail.

This is an explicit functional approximation, not TickTick date-strip visual parity. Individual reference icon actions and geometry remain unknown; do not invent quick-date buttons. Notes, completed/Won’t Do/Trash/archived task menus, Calendar/Board/iPhone, scheduling rules and persistence redesign are out of scope.

## Contract

Resolve the current unique editable record at opening and revalidate before saving. Date/Time/Duration/Repeat/Reminder drafts use the existing editor. Escape/outside dismissal discards staged changes; OK/clear follow existing save semantics. Navigation or row disappearance dismisses the presentation. It must work independently of docked/drawer/popup detail preferences and never retarget another selected task. Stale/deleted/locked records cannot be edited.

## Acceptance

Native test unselected-row targeting; dated/undated initialization; staged edit then Escape/outside dismissal with no write; successful save and No Date; removal from Today/filter without orphaned popover; locked/history/note omission; repeated opening and detail preferences. Existing schedule model tests remain relevant but do not prove native routing. Full suite, release/signature, independent review and exact-head CI required. No denied capture retry; actual screenshot only if supported.

## Verification

Candidate implementation; tests/release/review/native QA and CI pending. Light theme only.
