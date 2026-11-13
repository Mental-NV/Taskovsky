# Task-row Convert to Note

Status: implementation and verification pending.

Reference: `docs/ticktick-spec/tasks.md` records Convert to Note in an active task context menu. It does not establish complex conversion semantics or geometry. Taskovsky already offers conversion in the detail footer.

Bounded change: expose Convert to Note on active, nonarchived task rows. Resolve the unique current context-clicked record on activation, not selected detail or a captured snapshot. Reuse `TaskItem.converted(to:)` and `TaskStore.updateTask`; preserve their content, scheduling and graph policy. Notes, completed/Won't Do, Trash and archived rows are excluded. No new reverse row action or confirmation flow is inferred.

The existing detail conversion has no command-specific Undo. This slice does not introduce one or intercept native text Undo. Existing Convert to Task in the detail footer remains available; this is not a transaction rollback guarantee. Filtered rows may disappear when they cease matching a task-only query.

Verification gates: current-target/content preservation and eligibility tests, full suite/release, independent review, native unselected targeting/detail transition/task-only-filter removal and locked states. Actual screenshots and geometry remain unverified; no whole-panel or TickTick conversion-semantics parity claim.
