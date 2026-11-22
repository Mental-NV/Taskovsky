# MAC-CALENDAR-AGENDA-002 — Put Agenda times beside their cards

Status: candidate for [MAC-19](../mac-parity-acceptance.md#acceptance-matrix), macOS only. See [TT-033](../parity-implementation-status.md#tt-033) and [UX-017](../spec/ui-ux.md#ux-017).

## Evidence and intended behavior

The [dated installed TickTick observation](../ticktick-spec/calendar.md#shell-and-view-selection) shows a separate time column beside colored Agenda cards and a multi-day item repeated in applicable date groups. Exact column width, font, anchors, range and all-day wording, compact behavior and interaction parity remain unknown. The reference only establishes placement relative to the card; no visual-axis score is claimed.

On native Taskovsky `84b3111eca8f035adf676d3f014bf7ab4f0adf0c`, at 1060×700 and 382×584, the point (09:05) and range (10:35–11:45) labels were inside the tinted card beneath the title and to the right of its leading edge. The all-day control was present in two successive date groups, with the timed point then range in chronological order. AX included complete time and titles.

Give Agenda an aligned leading time column, separate from its cards. The same local point, range and All day wording is retained; the 88-point layout column is a Taskovsky choice, not a TickTick measurement. The card's existing accessible title/time and help remain intact; the visual copy does not add a duplicate announcement. Preserve recurrence and row/day projection, controls and style choices, calendar data and iPhone. Week/Day/Month continue using their existing card presentation.

## Acceptance

- At both widths, check point/range text and card edges visibly separate, aligned and legible; include an all-day span and a long title. Verify exact accessible point/time range without a duplicate element.
- Check multi-day items are still visible in both date groups, open a timed task, exercise the existing completion and Schedule Cancel paths, and ensure schedule data is unchanged.
- Verify Today empty, Agenda extension and at least one non-Agenda view as a negative control. Record pointer/keyboard/drag and reference limitations separately.
