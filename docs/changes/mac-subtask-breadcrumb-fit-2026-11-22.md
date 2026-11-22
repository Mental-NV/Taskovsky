# MAC-DETAIL-BREADCRUMB-001 — Keep linked-parent controls readable

Mac task detail, [MAC-05](../mac-parity-acceptance.md#acceptance-matrix), [TT-005](../parity-implementation-status.md#tt-005), [UX-008](../spec/ui-ux.md#ux-008).

A guarded native comparison at 1060 × 700 (2× app capture) with an approximately 300-point detail pane and a 91-character neutral parent name split the fixed “Subtask of” and “Remove” text across lines within words. A measured 300-point drawer in a 780 × 584 window repeated the same split. The parent remained linked and Change remained available; native Open Parent navigated successfully. The baseline product source for the detail is unchanged in `ce8892f`. This was a Taskovsky fit defect; the [dated TickTick reference](../ticktick-spec/tasks.md#child-task-creation-and-completion) establishes a parent breadcrumb but not exact narrow dimensions or truncation.

Reserve single-line intrinsic width for the fixed prefix and action labels and give the variable parent name the remaining width, tail-truncated if necessary. The first fixed-label candidate left a spacer competing for that space; reserving it for the title keeps more of the name visible. The parent link help also carries its full name. Preserve the full name for the parent link’s accessibility label, with “Untitled” when appropriate. Keep navigation, Change/Remove actions, locking, and the hierarchy model unchanged.

## Acceptance

- A long parent name must not break “Subtask of,” Change, or Remove across lines in the compact drawer and normal dock. The link stays on a single line with its full name exposed to accessibility.
- A shorter title stays readable; the link still navigates to the actual parent. Verify a reparent menu can present and dismiss without changing the graph, and that locked/non-navigable representations remain unchanged. Exact TickTick font, color and geometry are not claimed.
