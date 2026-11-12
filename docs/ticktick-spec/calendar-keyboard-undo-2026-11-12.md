# Calendar keyboard Undo: bounded Mac comparison

Reference: TickTick for Mac 8.2.20 (build 922), November 12, 2026. Taskovsky source inspected at `5783072`.

A disposable owned task was scheduled all day for November 13, 2026, then dragged in Month view to November 16. With Calendar focused and no text editor active, Command-Z did not restore its date. Command-Shift-Z also left it on November 16; the task date editor confirmed that date. Edit showed plain Undo and Redo, both disabled before the drag, after the drag, and after each shortcut. The task was explicitly restored to November 13 and retained in its QA list.

This is evidence for one all-day Month drag only. Timed moves, resize, other views, task completion and text editing were not tested. It is not proof that TickTick never supports schedule Undo.

Before live observation, MacDisassembler resolved the Calendar shortcut declaration and generated complete selected-function pseudocode for its bridge and direct callee. Numeric action dispatch did not identify an Undo route. This was a research lead, not runtime proof. Private recovered output was not added to the repository.

Taskovsky already provides its own guarded **Undo schedule** button. Its lack of Calendar-specific Command-Z routing is not a demonstrated parity defect for this tested interaction. Keep existing text/rich-editor Undo unchanged. Do not add a Calendar keyboard Undo/Redo stack solely from the older open-gap wording.
