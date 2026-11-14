# Mobile Priority board grouping

Status: In implementation, unverified. Implements a bounded backing capability for [the Sort & Group plan](mobile-sort-group-sheet-plan-2026-11-14.md), not that sheet or full reference parity.

The supplied mobile screenshot exposes Priority grouping independently from sorting. Add an opt-in Priority choice to the existing iPhone scoped Kanban grouping menu. Do not change defaults, Mac controls, concrete-list status/section boards or data. Use the existing destination membership/archive rules. Show populated priority lanes ordered by existing Taskovsky priority rank; preserve incoming task order within a lane. Label no-priority records “No Priority”. These ordering/empty-lane choices are explicit Taskovsky policies, not inferred TickTick behavior.

Priority lanes are display-only: no drag grips, drop targets/highlights or Move actions implying priority edits. Opening, completion and existing task-detail priority editing remain available. Changing a task's priority reprojects it; a removed selected lane falls back to the first populated lane. Empty destinations show a truthful empty state. Selection remains session-per-destination like existing grouping. Existing Date/List operations delegate unchanged to their shared projection.

Non-goals: tag subdivisions, tag sorting, new persistence, mutation/Undo commands, full Sort & Group sheet, new Mac grouping, inferred reference priorities/directions.

Verification required before merge: domain partition/scope/order/empty/notes tests; iPhone compile; independent review; native menu/selection/empty/current-lane-removal/completion/open and Date/List drag/Undo regressions; actual light-theme screenshot. Cloud has no Swift/Xcode runtime; no tests or native acceptance claimed yet.
