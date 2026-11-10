# CAL-HOURLY-RESIZE-002 — Adjust the start of a timed Calendar range

The active local Tasks and Calendar parity goal authorizes start-edge adjustment on Mac and iPhone. The isolated source is based at `6ee96ee`. The change applies to BUS-029, UX-017 and TT-033.

TickTick documents independent start and end editing for duration tasks, and edge resizing for duration blocks in its Timeline. The earlier Calendar comparison records Week edge resizing. Exact edge geometry and native gesture equivalence remain open. [TickTick Task Details](https://help.ticktick.com/articles/7055782408586526720), [TickTick Timeline guide](https://help.ticktick.com/articles/7055780375439605760).

The start handle changes the starting instant of an existing timed range. Its end, due time, time zone and reminders stay fixed. The grid snaps the proposed start in 15-minute steps. A changed range has a minimum duration of 15 elapsed minutes, with the end as the fixed clamp. A release at the unchanged start preserves legacy short or zero durations. Points and all-day ranges keep their current controls. Forecasts and independently projected checklist rows keep their read-only schedule controls.

On Mac the top handle occupies the width and height available beside the move grip and the lower resize handle. The preview shows the proposed start and disappears when the drag ends or is canceled. Clicking opens Schedule. On iPhone, a full-height hourly card exposes the top handle. A timed range also offers Resize Start through its card menu and accessible actions, including compact cards. The staged phone editor changes only the start and supports Cancel and the existing recurring scope choices.

The command uses the current schedule transaction, occurrence eligibility and guarded Undo. File formats stay at their current versions. Verification covers the fixed due time and reminders, the clamp, short-range no-op, clipped starts, native start/end control separation, Undo and relaunch. [Verification ledger](../spec/verification.md#calendar-timed-start-resize).
