# SCHEDULE-TIME-002 — Coherent Time and Duration controls

Source-backed defect: Time rendered raw hasTime, while an active Duration saves according to its own isAllDay. Remove time could display None yet save timed; All-day could leave a clock visible.

Time label, Add/Remove action, clock field and zone control now use ScheduleDraft.effectiveHasTime; displayed clock uses the effective due/end date. With active Duration, Add/Remove routes through the existing All-day conversion, the same action as the Duration All-day toggle. Removing time normalizes endpoints to civil days. Adding time uses existing conversion policy (09:00 start/end on respective days, at least one hour); it does not promise restoration of previous clocks. Without Duration, existing point and undated Time behavior is unchanged.

All changes remain staged until OK; Escape/outside dismissal discards. Existing default reminders refresh via the same conversion binding. No storage or notification permission change, and no claim about unobserved TickTick cross-control semantics.

Acceptance: timed duration Remove time updates both surfaces and saves all-day; All-day duration Add time updates both and saves timed; Duration All-day changes reflect immediately in Time; Cancel preserves original endpoints; point time and undated entry remain correct. Tests/review/build/native/CI pending; no screenshot or pixel-parity claim.
