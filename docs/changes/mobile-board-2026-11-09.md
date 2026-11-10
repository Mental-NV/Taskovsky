# MOB-BOARD-001 Status board on iPhone

This change implements the local Board behavior in [BUS-020](../spec/business.md#bus-020) and [the iPhone specification](../spec/iphone.md#ios-011). The [TickTick evidence](../parity-implementation-status.md#tt-022) establishes the presence of Kanban and persisted view state. Its custom-column behavior remains open.

A concrete active list has a List/Board selector. It writes that list's view mode and preserves other list values, tasks and settings. Archived lists display their saved mode with the selector and Board mutations disabled.

The phone pages Open, Completed and Won't Do with status tabs and counts. A card can move by dropping it on a tab or through its status menu. Local drops are tied to the source board and task. A note drop into a terminal column is refused. The board uses the shared task projection, including history independently of row visibility. Completion from Won't Do makes one durable lifecycle change. Undo restores the prior Won't Do timestamp and removes an untouched recurrence successor.

The [verification record](../spec/verification.md#nested-filter-layout) includes the Board simulator workflows, shared contracts and Mac fixture reloads. Custom columns and sections remain open.
