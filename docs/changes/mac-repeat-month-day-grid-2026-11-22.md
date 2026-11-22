# MAC-REPEAT-MONTH-001 — Select numbered monthly recurrence days

Mac Custom Repeat, [MAC-14](../mac-parity-acceptance.md#acceptance-matrix), [TT-014](../parity-implementation-status.md#tt-014), [BUS-013](../spec/business.md#bus-013).

The [November 3 native TickTick observation](../ticktick-spec/scheduling.md#custom-repeat-editor) saw Month → Each offer selectable days 1–31, Last Day and Skip Weekends. Guarded Taskovsky with the same current recurrence source showed a comma field and a separate last-day toggle. Native baseline proved that days 1 and 15 plus Last Day stage in the outer picker, Escape leaves the workspace byte-identical, and explicit OK persists the existing monthly rule. The reference did not exercise saving, weekends, or generated occurrences.

Replace only the Mac Each input with selectable numbered cells, a separately selectable Last Day, and a hint for Taskovsky’s existing scheduled-day fallback when nothing is selected. Expose each cell’s selection state; keep selections as a set in the editor and pass the same sorted array or nil to the recurrence model. The anchor, interval, weekday/ordinal/workday/year, weekend rules, preview, recurrence engine, and iPhone remain unchanged. Dimensions and colors are local choices, not measured TickTick values.

## Acceptance

Select, deselect and reopen days 1, 15 and 31; stage with Last Day, Cancel or Escape without writing, then Save and check the exact existing rule shape. Verify the initial empty fallback and the fixed footer on a compact host. If the added grid crowds another existing control, record the actual constraint. Reference engine equivalence and full geometry remain open.
