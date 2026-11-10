# CAL-FOLD-001 — Local Calendar folded hours

The [TickTick FAQ](https://help.ticktick.com/articles/7055792921664028672) describes independent early and late expansion in Calendar. The earlier [installed Mac audit](../calendar-visual-parity-audit-2026-11-08.md) saw 07 and 21 ruler handles. Taskovsky uses the documented default bands and named controls on Mac and iPhone. The expanded or folded state is temporary. It resets when the hourly view is recreated and does not update either file.

With default settings, Day, Week and Multi-Day display 07:00 through the 21:00 boundary. Early hours adds 00:00–07:00, and Late hours adds 21:00–24:00. Each control shows how many visible-source timed items overlap its band, including portions of entries that cross a boundary. All-day rows and non-hourly modes keep their existing behavior.

Timed cards are clipped at the visible boundaries. An end hidden by a folded band has no direct resize handle until that band is expanded. Full details and staged Schedule remain available for a visible card. The shared conversion adds the current visible start to a pointer offset before snapping to wall time. A short duration resizes from its actual endpoint. View bounds constrain direct gestures and never rewrite a schedule by folding or unfolding.

## Adjustable cutoffs

Expand both bands to reveal the two cutoff markers in the primary ruler. Drag a marker by a whole hour to change its boundary. The marker previews its proposed position during the drag and saves on release. Keyboard and accessibility users can use the View Options controls. The phone stages those controls until Done. Reset Folded Hours restores 07:00 and 21:00. Each folded band and the middle timeline retain at least one hour.

Saved cutoffs apply to Day, Week and Multi-Day and survive relaunch. Expanding either band still changes view state only. Counts and timed-card placement use the new boundaries, and the displayed timeline continues to map gestures to wall time. The cutoffs affect Calendar settings only. Timeline zoom remains separate.

The [TickTick FAQ](https://help.ticktick.com/articles/7055792921664028672) documents dragging the timeline bar with both bands expanded. Taskovsky uses whole hours, saves the cutoffs locally and offers precise View Options controls. [Cutoff verification](../spec/verification.md#calendar-adjustable-cutoffs).

[Verification record](../spec/verification.md#calendar-folded-hours).
