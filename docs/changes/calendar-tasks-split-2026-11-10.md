# CAL-SPLIT-001 — Show Tasks with Calendar on Mac

The active local Tasks and Calendar parity goal authorizes this Mac workspace change. It updates BUS-027, BUS-029, UX-017 and TT-033. The installed TickTick 8.2.20 build 922 English resources contain `show_calendar_in_list` and `split_view_guide`. They identify the Tasks icon context action that opens both surfaces. The June 2024 changelog documents list-to-Calendar drag scheduling. [TickTick changelog](https://ticktick.com/public/changelog/en.html).

Right-click Tasks and choose Show with Calendar. The left pane retains the task destination, quick entry, lists and task details overlay. The right pane is the same local Calendar view with its own toolbar, projection, filters, and scheduling feedback. A native divider resizes the panes while retaining their minimum widths. When the window has insufficient space, Tasks uses its regular layout and the saved split preference resumes on expansion. The Calendar rail still opens the full Calendar workspace. The Tasks icon can hide the split. A Mac preference remembers the chosen layout.

Drag a task row grip into a Calendar day, all-day strip or time grid to use the existing Calendar schedule command, including recurring scope selection and schedule-only Undo. Tasks and Calendar share the existing private task drag type. Calendar accepts one task per drop. List and section drops retain their current behavior. The task ID stays within Taskovsky. The split itself writes no workspace data, and iPhone keeps its current layout.

The June 2026 changelog mentions a configurable split shortcut. The installed shortcut binding and exact split geometry are open. Verify native toggle, width fallback and return, the existing full Calendar, list-to-grid drag and Undo, persistence, and unchanged unrelated file fields using the isolated QA app.

[Verification ledger](../spec/verification.md#calendar-tasks-split).
