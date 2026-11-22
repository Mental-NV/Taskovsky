# MAC-CALENDAR-COLOR-002 — Keep both List Colors actions readable

Status: candidate for [MAC-20](../mac-parity-acceptance.md#acceptance-matrix), Mac only. See [UX-017](../spec/ui-ux.md#ux-017) and the [shared List Colors contract](mac-calendar-shared-list-color-2026-11-12.md).

Native List Colors at 1060×700 and 382×584 clipped the visible tails of **Cancel Calendar Changes** and **Save Calendar Changes** in one footer row. This was observed before and after [folder grouping](mac-calendar-list-color-folders-2026-11-22.md). Tag **Cancel** and **Done** fit. Dated TickTick did not establish equivalent footer actions; this is a local readability correction.

Keep the full labels and their native Escape/Return equivalents, trailing aligned on two separate rows in List Colors. The Tag footer remains unchanged. Both List controls still affect only staged Calendar overrides; a named-list color already saved inline via **Apply** is still immediate. Do not alter sheet width, row colors, data, domain logic, legacy handling, or iPhone.

## Acceptance

- At normal and minimum host size, both button labels are fully visible and actionable without reducing font size; the last list row is reachable separately via scroll.
- On a disposable legacy override, Use List Color followed by Cancel preserves the override. Repeat and save; only that override is cleared, not the shared list color or other settings. Verify the keyboard and pointer paths separately where possible.
- Tag stays horizontal, and opening the settings without changes has no workspace effect.
