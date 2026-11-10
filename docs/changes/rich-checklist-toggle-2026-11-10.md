# RICH-CHECKLIST-001 — Toggle description checkboxes directly

The autonomous local Tasks and Calendar parity goal authorizes this Mac and iPhone follow-up. It refines [BUS-005](../spec/business.md#bus-005), [UX-009](../spec/ui-ux.md#ux-009) and [TT-003](../parity-implementation-status.md#tt-003). TickTick documents description checklists in its editor. Taskovsky already stores checked state and offers formatting commands. This change makes the rendered checkbox actionable in both rich editors. [TickTick editing guide](https://help.ticktick.com/articles/7507338582718152704).

Click or tap a checkbox in the editable description to flip that paragraph only. The target stays in the existing first-line gutter, including on wrapped items. Text, bullet and number interactions retain the editor’s ordinary selection behavior. Keyboard and assistive technology can still use the named toolbar commands. Reading and folded previews remain selectable and read-only.

Preserve the exact body, existing inline and paragraph formatting, neighboring checkboxes, embedded task checklist items, linked subtasks, schedules and settings. Reuse the existing checked flag and editor history. Mac saves through its existing body change callback. iPhone stages the edit, supports Undo/Redo and recovery, and follows Done and Cancel. Verify both directions, independent items, untouched text and nearby gutter hits, Undo/Redo, reopened state, and iPhone cancellation.

[Verification record](../spec/verification.md#rich-checklist-toggle).
