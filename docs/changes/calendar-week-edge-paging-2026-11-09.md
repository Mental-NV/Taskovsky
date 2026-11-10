# Week edge paging during an iPhone Calendar drag

9 November 2026 · CAL-WEEK-EDGE-001

TickTick documents holding a dragged task at the screen edge to move to another week. Taskovsky offers this navigation in iPhone Week for local Calendar drag payloads. The edge shows a direction indicator and pages once after a short dwell. Moving away, releasing, or cancelling ends the dwell. Enter an edge again to page another week. [TickTick Week guide](https://help.ticktick.com/articles/7055782149730861056#easily-adjust-task-time).

Paging changes the visible focus date. Releasing on an edge leaves the workspace and settings untouched. Moving inward and dropping on an all-day date or a time uses the existing revision-checked scheduling operation, including the recurring-scope prompt where applicable.

The simulator checks exercise a quick release, both paging directions, ordinary horizontal scrolling, existing timed and all-day drops, and existing resize and Undo. They use separate touch sequences for edge paging and the subsequent drop-path checks. Freeform drag auto-scroll, other views, and exact reference timing remain outside this change.
