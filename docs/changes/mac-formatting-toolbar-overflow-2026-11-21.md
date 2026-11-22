# MAC-DETAIL-FORMAT-002 — Reach tools in a narrow task detail

Status: implementation candidate. macOS detail only; base `da2c3e877e4d05432b86664aab8d022ba5bd1854`. See [UX-008](../spec/ui-ux.md#ux-008--detail-drafts-hierarchy-and-reminders), [TT-002](../parity-implementation-status.md#tt-002), and the [contextual controls contract](mac-detail-contextual-controls-2026-11-13.md).

## Evidence and scope

In the guarded light-mode Taskovsky fixture at the base revision, a 780 × 580 capture of the compact drawer showed the expanded formatting row ending around Code Block, with Clear Formatting and Insert Horizontal Rule clipped. The accessibility tree still listed them. Horizontal wheel attempts on the row did not move the viewport, and ordinary Tab reached the native editor and inserted literal tabs. This is evidence for those inputs only, not failure of a physical trackpad or Full Keyboard Access. Body wheel scrolling moved from paragraph 1 to 13 while toolbar and footer stayed fixed.

The [TickTick editing guide](https://help.ticktick.com/articles/7507338582718152704) establishes a bottom desktop toolbar and an editing menu. The exact compact TickTick behavior and geometry have not been observed. The overflow popover is a deliberate Taskovsky fallback, not a replica of an observed reference control. No screenshot was exported.

Provide a named **Show all formatting tools** button at widths where the original tool strip does not fit. Keep the horizontal strip available and put its existing commands in two visible rows above the footer when requested. Reuse the same rich editor controller and leave the normal non-overflow row, task-selection reset, keyboard shortcuts, title/body ownership, and file/business rules unchanged. Link from the expanded palette has its own presentation state. Do not change progress as part of this patch.

In the base fixture, idle 35% displayed a thin partial blue line without a number; Cancel preserved 35% and Done persisted 36%. A 1/2 complete checklist exposed read-only 50%; a note had no progress control. Pure hover/leave was not tested because the native input tool lacked an unmodified pointer-move action. No TickTick data changed.

## Acceptance

- On compact detail, open the named button and use a previously offscreen tail tool on a synthetic description selection. Verify the action and Undo; do not rely on accessibility listing alone.
- Escape and outside click dismiss without edits; reopen, check nested Link Cancel, and switch tasks or widen the pane without stale presentation. When the original strip fits, avoid a redundant overflow button.
- Show/hide the footer toolbar and scroll a long body independently. Verify no changes to progress, iPhone, persistence, editor keyboard shortcuts or default collapsed state.

Actual device behavior, known limits and exact-head checks will be recorded separately from source review.
