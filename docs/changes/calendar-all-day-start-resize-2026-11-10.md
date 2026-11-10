# CAL-ALLDAY-RESIZE-002 — Adjust the start of an all-day Calendar range

The local Tasks and Calendar parity goal authorizes this change on Mac and iPhone. It applies to BUS-029, UX-017 and TT-033. TickTick documents editing the start and end of a multi-day all-day duration. The shipped reference evidence leaves the exact all-day drag geometry open. [TickTick Task Details](https://help.ticktick.com/articles/7055782408586526720).

Week, Multi-Day, Month and Multi-Week offer a leading resize handle on the visible segment that contains the true start. The trailing end handle stays on the segment that contains the true end. A one-day duration keeps both handles. On iPhone, narrow single-date bars use compact grips and truncate the title within the date cell. Date-only points and forecast occurrences keep their existing controls. The staged iPhone Resize Start action is available from a duration's card menu and accessibility actions, including Day view. Clicking the Mac handle opens Schedule.

The drag selects an inclusive display date and maps it to the corresponding civil day in the task's time zone. The start cannot pass the due day. A release on the original start makes no change. The end, due day, zone, reminder dates and reminder provenance stay fixed. Existing Calendar transactions, recurring scope eligibility and guarded Undo apply. The data format stays at its current version.

Verification covers inclusive civil dates across a daylight-saving boundary, unchanged due day and reminder provenance, the one-day clamp, projected rows, continuation segments, staged cancellation, Undo and relaunch.

[Verification ledger](../spec/verification.md#calendar-all-day-start-resize).
