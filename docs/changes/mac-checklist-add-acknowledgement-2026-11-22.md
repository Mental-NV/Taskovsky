# MAC-DETAIL-CHECKLIST-001 — Keep the checklist draft on a failed Add

Mac Tasks, [MAC-05 and MAC-07](../mac-parity-acceptance.md#acceptance-matrix), [UX-008](../spec/ui-ux.md#ux-008). Linked subtasks, existing checklist editing, and iPhone are out of this change.

Guarded baseline product `bbe0717` verified that provisional checklist and linked-subtask text survived different tasks, a closed compact drawer, and re-docking the original task. But a forced failure on a disposable workspace write displayed the storage Retry banner and emptied the unsaved checklist field, while the linked-subtask field stayed intact and disk bytes were unchanged. The old append path also published the new record to in-memory state before it knew whether the save worked.

The Mac Add action now uses the existing narrow metadata transaction: append to the current eligible task, write the staged workspace, and publish only on success. Keep the field and focus when the write fails. Successfully adding clears only its own draft. The general workspace Retry is not a substitute for Add. No storage schema, recovery mechanism, or TickTick failure semantics change.

## Acceptance

- A rejected write preserves both the previous workspace and the exact draft, with no phantom checklist row or duplicate. Restore the disposable destination, submit again, and reload exactly one new trimmed unchecked item, with unrelated task records unchanged.
- Blank/missing/locked items do not write. Keep already verified draft isolation on task switching and resize. Check the ordinary Return action and companion draft state. Distinguish automated failed-write tests from native field checks; do not label this newly observed TickTick behavior.
