# CAL-HOURLY-MOVE-001 — Move a timed Calendar card with its own grip

This change addresses the native short-window move gap on the isolated local parity line at `6ee96ee`. It applies to the shared Mac hourly grid in Day, Week and Multi-Day. The related requirements are BUS-029, UX-017 and TT-033.

The Mac card has a trailing move grip with a time preview. Click or activate the grip to open the existing Schedule editor. Drag within the visible hourly area to move using the same pointer anchoring and 15-minute snapping as a native hourly drop. The destination follows the current scroll position, date columns, time rulers and zoom. Releasing outside the visible hourly area leaves the schedule intact. The bottom grip still resizes the end, and the original card drag path remains available for other drop surfaces.

The move calls the existing Calendar transaction and uses the same recurring scope prompt, reminder policy and guarded Undo. A short range retains its exact elapsed seconds, and a point retains its shape. The grip holds transient preview state. Workspace and settings formats keep their current versions.

The initial native QA reproduced an unchanged short-card body drag and verified resize and Undo separately. The follow-up checks exact duration, reminder shifts, cross-day and same-day destinations, the scrolled grid, out-of-grid release and saved schedules after relaunch. iPhone keeps its existing native touch grip and shares the schedule transaction. [Verification ledger](../spec/verification.md#calendar-timed-move-grip).
