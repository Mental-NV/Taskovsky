# TASK-HIERARCHY-002 — Expand and collapse linked subtasks in Lists

The active local Tasks and Calendar parity goal covers native List rows on Mac and iPhone. [Hierarchy rule](../spec/business.md#bus-006) · [List rows](../spec/ui-ux.md#ux-006) · [Verification](../spec/verification.md#task-subtree-disclosure).

The installed TickTick Mac app showed a disclosure control and child indicator after adding a subtask. The web changelog confirms expand and collapse commands. Persistence, keyboard bindings and exact appearance across platforms remain open. [Mac task hierarchy observation](../ticktick-spec/tasks.md#child-task-creation-and-completion) · [TickTick changelog](https://ticktick.com/public/changelog/).

- A task row with children in its current rendered group shows a chevron with a named accessible button. The button hides or shows that branch without changing selection, completion, order, saved fields or settings. Nested branches retain their independent expansion state when an ancestor is hidden and reopened.
- Folds are scoped to the task identity in the current window or phone session. They survive navigation during that session. All branches start expanded after relaunch.
- The projection hides only descendants nested under the visible row in the same group. A child outside that group, such as a filtered result or separately pinned row, stays independently visible. The parent’s progress indicator and the group count continue to represent the underlying tasks.
- Mac keeps the existing title and drag-grip positions and places the chevron in the row gutter. The iPhone uses a separate trailing touch target. Both are distinct from the title, completion and checklist controls. The Mac row menu opens a folded parent when it creates a new child and selects that child. While a title is being edited inline, collapsing a branch in that group waits for the user to finish or cancel the rename.
- Search results, Board, Timeline, Calendar, batch selection and task detail keep their existing presentation. No schema or workspace writer changes.

Verify nested branches, separate groups and filters, selected detail, keyboard/accessibility labels, navigation and relaunch with disposable Mac and iPhone workspaces. Compare the task and settings bytes before and after.


## Recovery on November 12, 2026

This implementation-only finishing slice follows the user's request to complete the previously unfinished work. Its exact integration base is PR #30 head `e594db764abfe569e2a77c2cb411c2c70ef9b3ba`. It is a separate stacked change, not authorization to merge either PR. Source was recovered from the preserved draft; current iPhone manual reorder, countdown and section controls are retained. There is no file schema change, shared editor refactor or external integration.

Mac chevrons use an 8-point semibold secondary symbol in the existing 12 × 24 leading gutter without moving the grip/title. iPhone uses a secondary semibold caption symbol in a separate 44 × 44 trailing target. No additional animations are introduced. Current verification and its limits are recorded separately in the ledger.
