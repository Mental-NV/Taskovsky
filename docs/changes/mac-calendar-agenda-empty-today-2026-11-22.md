# MAC-AGENDA-TODAY-001 — Illustrate empty Today in Agenda

Mac Calendar, [MAC-19](../mac-parity-acceptance.md#acceptance-matrix), [TT-033](../parity-implementation-status.md#tt-033), [UX-017](../spec/ui-ux.md#ux-017). Base `6fe92cd14371961463eed9bd8ce777a8bf30a680`.

The [November 2 actual TickTick observation](../ticktick-spec/calendar.md#shell-and-view-selection) described an illustrated “No tasks today” state under the current Agenda date group. Equivalent guarded Taskovsky Calendar product source instead showed plain “No scheduled tasks” at normal and minimum host widths. The same generic text was correct for its separate non-Today state; its TickTick equivalent was not observed. Show more extended the horizon and Today reset it as intended.

Replace only the existing rendered, empty current-day row with the observed wording and a centered, decorative Taskovsky calendar glyph. Keep date grouping, Today detection, future day contents, Add, Show more and horizon logic unchanged. Do not add empty groups or copy TickTick art. Exact dimensions, colors, and reference placement are not newly measured.

## Acceptance

Check the current-day heading and empty banner at normal and minimum widths. The glyph should be decorative with a single accessible instruction; Add and the horizon/footer remain reachable. Navigate to a non-Today Empty and verify it retains generic copy, Show more extends the horizon, and Today returns to the current-day banner. A populated day should not display a misleading empty banner. No real data or reference changes.
