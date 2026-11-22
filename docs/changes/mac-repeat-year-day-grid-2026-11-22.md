# MAC-REPEAT-YEAR-001 — Make the yearly day selectable

Status: candidate for [MAC-14](../mac-parity-acceptance.md#acceptance-matrix), Mac only. See [TT-014](../parity-implementation-status.md#tt-014).

The [dated installed TickTick observation](../ticktick-spec/scheduling.md#custom-repeat-editor) showed selectable Year days in a navigable month/day grid, with separate **Each** and **On the** modes. Exact day cardinality, invalid-date behavior, mode transitions and geometry were not established.

Guarded Taskovsky on `56cfd8aedaa622240e6974e9bd0659aafe5a2d23` showed a month picker, a free-text Day field, ordinal and weekday controls together. This change addresses just the day input: reuse the numbered control style from the monthly editor with selection of one existing allowed day, or clearing to the scheduled day. The existing month picker and separate ordinal controls are retained. No change to persisted rule fields, fallback, ordinal precedence, range validity, occurrence generation or iPhone. A separate Year mode/geometry comparison remains open.

## Acceptance

- Confirm the day controls fit and remain selectable at normal and minimum host sizes. Select day 15, then 31; only the final selection remains. Clear explicitly to the scheduled-day fallback.
- Stage a Year month/day without writing, outer Escape; repeat and explicitly save, reopen to verify the original field shape. Exercise the original ordinal path or record its limit.
- Confirm the existing Month grid still supports multiple simultaneous values and Last Day. Do not infer exact reference selections, leap-year policy or visual score.
