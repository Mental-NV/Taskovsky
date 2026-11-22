# MAC-CALENDAR-COLOR-001 — Show folder membership in List Colors

Status: candidate for [MAC-20](../mac-parity-acceptance.md#acceptance-matrix), Mac only. See [TT-033](../parity-implementation-status.md#tt-033) and [UX-017](../spec/ui-ux.md#ux-017).

The [dated installed TickTick observation](../ticktick-spec/calendar.md#view-options) showed a folder/list tree with color markers in the Task → List Color settings. Folder disclosure, all colors, mutation behavior and exact geometry were not established.

Guarded Taskovsky on the product tree in `5b0d171557d0130ce51ce8cf83680f9db90ebcba` opened the List Colors editor. At 1060×700, two same-named lists owned by different folders appeared flat at the same horizontal position, their colors distinguishable but their folders not indicated. Inbox and the root control were present; archived entries were excluded.

Use the existing Calendar List Color grouping for Inbox, root lists and named folders. Show headings and indented member rows, not expandable controls. The heading appearance and indent are Taskovsky layout choices, not reference measurements. The existing swatches, named-list saves, Inbox and legacy overrides, Tag list, Priority and persisted rules stay unchanged. Existing footer truncation is separate.

## Acceptance

- Verify two same-named, independently colored lists appear in the appropriate folders at normal and minimum width; Inbox and root remain unindented and archived lists stay hidden.
- Check one row color control under each heading, scope-specific Cancel, and unchanged fixture data. If exercising a writer, use one isolated named list and confirm its sibling's color and identity remain unchanged.
- Check Tag/Priority retain their existing structure and behavior. Do not infer collapsing, exact geometry or reference settings mutation.
