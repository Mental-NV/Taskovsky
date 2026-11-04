# Eisenhower Matrix: observed behavior

This module is outside the original Taskovsky implementation scope. Inspection used the installed macOS app in light appearance on 3 November 2026; task contents and account configuration are omitted.

## Layout and grouping

The workspace has a title and top-right overflow, with four independently scrollable rounded panels in a two-by-two grid. Each panel begins with a colored circular Roman numeral and title: I **Urgent & Important** (red), II **Not Urgent & Important** (orange), III **Urgent & Unimportant** (blue), IV **Not Urgent & Unimportant** (green). Tasks are grouped by date/status, including Overdue, Next 7 Days, Later, No Date and Completed in the observed account. Group headings have disclosure controls and counts. Rows can include a checkbox, title, list, date, tag, recurrence, note or subtask indicators; completed rows and metadata are muted. Precise geometry, colors and typography have not been measured.

## Priority mapping

A disposable task with no due date was restored from Trash and used as a controlled probe. Choosing the red priority flag in its ordinary task context menu placed it in quadrant I, under No Date, with a red checkbox outline. Choosing orange in its matrix context menu moved it to quadrant II, with an orange outline and a transient `Moved to "Not Urgent & Important"` toast. Choosing blue moved it to III and showed the corresponding toast; choosing the outlined no-priority flag produced a `Moved to "Not Urgent & Unimportant"` toast for IV. This establishes the four observed priority-to-quadrant mappings for this task, but does not by itself establish every inclusion rule for notes, subtasks, recurring instances or archived lists.

One attempt to drag the task from I to II left it in place. This single gesture is insufficient to conclude that drag-and-drop is unsupported. The probe was reset to no priority and returned to recoverable Trash.

## Actions and completed visibility

Right-clicking an active task exposes the ordinary task context menu, including date shortcuts, priority flags, Add Subtask, Link Parent Task, Pin, Won't Do, Move to, Tags, Start Focus, Duplicate, Copy Link, Open as Sticky Note, Convert to Note and Delete. Changing priority from that menu moved the probe between panels as described above.

With completed items visible, the workspace overflow offered **Hide Completed**. Choosing it removed Completed groups from all four panels; panels with no remaining tasks displayed centered `No tasks`. The menu then offered **Show Completed**, which restored the prior display. This was a temporary display change; long-term persistence was not checked.

## Remaining evidence

Inspect task selection/detail, checkbox completion and undo within the matrix, date changes and grouping transitions, subtask and recurrence behavior, drag gestures, scroll independence and persistence, empty states across all priorities, keyboard/hover interactions, responsive geometry and animation. The observed mapping is not proof of all filtering semantics.
