# TASK-MOBILE-SWIPE-001 — Quick actions from iPhone task rows

TickTick documents horizontal swipes for task completion, due date, priority and list changes. Taskovsky gives its iPhone Tasks list rows fixed leading and trailing actions. [TickTick swipe actions](https://blog.ticktick.com/2020/12/08/20-lesser-known-ticktick-features/).

The leading edge reveals Complete or Reopen for eligible tasks and Restore for items in Trash. The trailing edge reveals the applicable Schedule, Priority, Move and Trash actions. A horizontal swipe reveals buttons. A tap runs the chosen action. Swiping alone leaves data intact. Opposite motion can close the row, and a different row or destination closes the previous row. A vertical gesture scrolls the list. The existing checkbox, title, section grip and detail actions remain separate.

Schedule, Priority and Move open the existing staged editors or destination picker. The [Schedule editor](mobile-task-schedule-skip-2026-11-10.md) can stage a skip for an eligible recurring task. Completion, reopening, Trash, Restore and Move use the revision-checked lifecycle command and its existing Undo. Eligibility comes from the same task status and archive rules as detail. Notes lack completion and schedule. Permanent deletion remains in task detail with its named confirmation.

The assignment is a Taskovsky choice. Per-direction customization and exact reference defaults remain open. The phone keeps the same local task and settings schema.

Recurring cards in Agenda and Month have a separate [Calendar swipe](mobile-calendar-card-swipe-2026-11-10.md) to open the Schedule editor.

[Verification](../spec/verification.md#mobile-task-row-swipes).
