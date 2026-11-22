# LIST-VIS-002 — Show the List preview at wide workspace widths

Status: candidate. Mac Add/Edit List only. Baseline `7d4911b9f8f5ed4b7543788b15b6917bcab4261e`. [MAC-12](../mac-parity-acceptance.md#acceptance-matrix), [TT-017](../parity-implementation-status.md#tt-017), [LIST-VIS-001](mac-list-editor-preview-2026-11-13.md).

## Native baseline and change

A guarded light-mode fixture reached the real form-only layout on a 382-point host (764 capture pixels at 2×). The form fit, the empty Create button stayed disabled, a 144-character draft could be canceled, and a synthetic List round-tripped Timeline then Board. On a freshly launched 1060-point host, New and Edit were both still 360 points wide, with neither preview nor preview accessibility summary. This was not simply the same sheet staying narrow after resizing. Its segmented selector also described only List/Board even though Timeline was selectable.

The old `ViewThatFits` depended on the sheet's self-proposed width, not available width on the workspace. Use the measured workspace width for the 360-point form plus existing 280-point preview; below 640 points use the same form alone. Keep Tag as 360 points. The form remains the first child in either layout, with the same draft, save/Cancel and stored mode. The selector label names the display mode and its help includes all three choices. Timeline stays a supported stored mode with no live preview rendering.

The dated [TickTick reference](../ticktick-spec/lists-and-tags.md#addedit-list-dialog) establishes a two-pane Add/Edit List with responsive List/Board previews. The compact reference fallback and exact preview geometry are not freshly verified.

## Acceptance

- Use a guarded actual Mac workspace at minimum or compact and wide widths, checking true form-only fallback and the visible illustrative wide-pane preview on real sheet presentation. Check both sides of the boundary in sizing tests. Normal screenshot scale is not a substitute for host width.
- Check Create disabled on blank, focus to List name, full footer with long draft, Cancel without writes; select and persist Board or Timeline and reopen. In wide mode, switch List/Board and check preview changes and Timeline explicitly reports unavailable. Verify Tag remains form-only and safe on Cancel.
