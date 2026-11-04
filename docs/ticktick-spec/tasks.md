# Tasks: context actions and hierarchy

Evidence in this section comes from a disposable Inbox task in the installed TickTick macOS app on 2 November 2026. The parent was subsequently moved to recoverable Trash. A blank probe row remained visible in Completed after that deletion and was separately moved to Trash; the exact parent-deletion behavior for every child requires further verification. The observations describe that single state and do not establish all edge cases.

## Active task context menu

Right-clicking the selected active task's row opened a white, rounded, shadowed vertical menu. At its top were a Date icon strip and Priority strip: red, orange, blue and outline flags. Below a separator the observed actions were **Add Subtask**, **Link Parent Task**, **Pin**, **Won't Do**, **Move to** (submenu), **Tags** (submenu), **Start Focus** (submenu), **Duplicate**, **Copy Link**, **Open as Sticky Note**, **Convert to Note**, and **Delete**. Menu items had leading outline icons; submenu rows had right-pointing chevrons. This was a task with no date or children; menu contents may differ for other states. Submenu entries and most actions remain to be inspected.

Choosing **Pin** immediately removed the probe from its No Date group and placed it in a new **Pinned** section above Overdue. Its row stayed selected. A subsequent context menu changed the action label to **Unpin**. This establishes the observed grouping transition, not how pinned items sort in every list, search, or view. Taskovsky's current [task model](../../Sources/TaskovskyCore/Models.swift) and [row context menu](../../Sources/Taskovsky/App.swift) contain no corresponding pin state/action; this is a confirmed gap.

## Child task creation and completion

Selecting **Add Subtask** on the pinned parent immediately added an indented, selected child row with a `No Title` field. The parent acquired a disclosure control and a child indicator. Typing a child title and pressing Return created another blank child row; the group count increased for each row, including the blank one. Pressing Escape after this did not remove the blank row in the observed state. Do not assume this applies to every creation entry point or that a blank child has identical persistence semantics without further testing.

Selecting the titled child opened its own detail pane with a parent breadcrumb, its own completion checkbox, Due Date, priority flag, title, body and Add Subtask control. The list displayed the child indented beneath the parent. This is a task hierarchy with separately selectable detail, not merely a string in the parent's description. Individual scheduling and deeper nesting were visible as controls but were not exercised.

With two unchecked children (one blank), clicking the parent's checkbox immediately moved the parent and both child rows from Pinned into the Completed section and showed the transient `Task completed` Undo toast. The selected child's detail then displayed a checked completion control. No confirmation appeared in this particular case. Whether completion propagates identically to dated, recurring, previously completed or deeper descendants, and exactly what Undo/reopen does to each child, still needs testing.

Taskovsky stores each checklist entry as an ID, title and completion flag embedded in the parent ([model](../../Sources/TaskovskyCore/Models.swift)); it does not store independently schedulable child tasks or parent links. Its checklist can be toggled and edited, but the observed TickTick hierarchy, child detail and parent-completion propagation are not equivalent. The earlier parity table's broad “subtasks implemented” language should therefore be read as checklist support only.

## Further experiments

Inspect unpin and order persistence, parent-link selection and cycles, multiple hierarchy levels, child reparenting, independent child completion/reopening, deletion and restoration of parent versus child, recurrence interaction, add-entry keyboard behavior, empty-title cleanup, and every context submenu. Compare task/note/complete/deleted and multi-select context menus, including all disabled and hover states. Measure menu and row geometry at known scale.
