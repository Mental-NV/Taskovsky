# TASK-TIME-001 — Reveal full task schedules with Option

The autonomous local Tasks and Calendar parity goal authorizes this Mac follow-up. It refines [BUS-011](../spec/business.md#bus-011) and the [UX-005](../spec/ui-ux.md#ux-005). TickTick documents holding Option to see full task times in Task View. Taskovsky currently shows a compact due label in List and a date in Board. [TickTick Mac changelog](https://ticktick.com/public/changelog/en.html).

Hold Option in the key workspace window to reveal the full schedule of dated tasks in List and Board. Points show a civil date and the time when applicable. A timed range shows both endpoints and a cross-day range includes both dates. All-day schedules show dates. Times use the existing task time-zone formatting. Dated rows temporarily give the schedule the trailing metadata space. Undated tasks keep their existing metadata. Compact List rows can wrap the schedule within the existing metadata budget. Release Option to return to the regular row. The schedule remains available as tooltip and accessibility text while revealed.

Use the existing key-window, sheet and application-modal guards also used by Calendar. In a split workspace, Option can reveal task times and Calendar icons together. Holding and releasing it changes only presentation. Verify scoped activation, release, focus loss, all-day dates, timed points, same-day and overnight ranges, and byte-identical workspace and settings files.

[Verification record](../spec/verification.md#task-option-times).
