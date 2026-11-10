# All-day ranges in Calendar

9 November 2026 · CAL-ALL-DAY-SPANS-001

TickTick’s Week view displayed all-day and multi-day bars in a strip above its hourly grid. Multi-Day used the same arrangement with five visible columns in the inspected account. [Calendar survey](../ticktick-spec/calendar.md#shell-and-view-selection).

Taskovsky’s Week and Multi-Day use a shared civil-day projection for all-day ranges. A range occupies one continuous bar across its visible dates. Intersecting ranges use separate rows, and a later non-overlapping range can reuse a row. The visible window clips each range at its edges. A range crossing a daylight-saving transition uses calendar day boundaries.

The existing automatic and fixed row counts apply to the resulting rows. If the strip overflows, its rows scroll together across the visible dates. Single-day entries continue to use the existing layout when no visible range spans or continues beyond a day. Mac Day view announces whether a clipped range continues before or after the current date.

On iPhone, the drag grip moved a three-day range to Thursday, preserved its three calendar dates and left the overlapping range unchanged in the saved workspace. The Mac rendering and Day continuation labels were observed in a guarded native app. The Mac card body left the range in place during two drop attempts. With the dedicated grip, the same three-day range moved from November 9–11 to November 12–14 and kept the overlapping range unchanged. Undo restored the original scheduling fields and updated the task’s modification timestamp. The disposable fixture and QA preferences were restored after closing the app.

Month and Multi-Week show one segment per week row. Each segment spans its covered dates. Intersecting ranges reserve separate lanes, and each date fills the remaining lanes with its local cards. The overflow count includes hidden ranges and local cards. Mac opens the date’s overflow sheet, and iPhone opens Day. In the native Mac check a five-day range continued across two week rows. Dragging the continuation moved November 13–17 to November 11–15. Undo restored the schedule. On iPhone, the Month and Multi-Week segments and the Saturday overflow count were verified, along with the existing Month zoom and point-task drop.

On Mac, drag from an empty date cell to another date in Month or Multi-Week. The selected range opens the staged Calendar editor with inclusive all-day endpoints. Dragging backward uses the same date order. Cancel leaves the workspace unchanged, and Add Task creates one scheduled task.

On iPhone, hold an empty date cell in Month or Multi-Week and drag to another date to stage the same inclusive range. The regular capture sheet keeps both dates through local recovery. [iPhone range capture](mobile-calendar-range-capture-2026-11-09.md).

[All-day end resize](calendar-all-day-resize-2026-11-09.md) works on the final visible segment in Week, Multi-Day, Month and Multi-Week. Drag auto-scroll and exact reference drag anchoring remain open. External calendar integrations are deliberately deferred. [Scope decision](../ticktick-spec/taskovsky-parity.md#calendar-integrations-deliberately-deferred--8-november-2026).
