# Durable Mac List editor Save

Status: implemented bounded correction after an owned blocked-write regression failed for both create and edit. Independent design/implementation review passed.

The explicit New/Edit List sheet currently calls legacy optimistic list saves and dismisses without a durable acknowledgement. New Board/Timeline lists require a second write after creation. This change is limited to that sheet: one staged list record includes name, color, kind, icon, view, folder placement and smart-list inclusion before one atomic workspace replacement. Creation uses a stable draft UUID. Other list operations, tag/folder sheets and iPhone remain separate.

Edit must carry its original saved list snapshot, including fields not editable in the sheet. Refuse stale or missing snapshots rather than overwrite concurrent folder/view/color/pin/archive/section changes. Preserve current established name/icon normalization, list ordering and folder placement rules; do not introduce new validation or automatic navigation on failure. Successful new creation navigates only after durable acknowledgement; failure retains all draft fields and displays an actionable error. Cancel remains non-saving.

Read current persisted bytes and require decoded equality with the store; recheck exact bytes immediately before replacement. Patch only changed list fields, preserve unchanged raw and unknown data plus all unrelated JSON, and validate the result matches the staged model. Refuse ambiguous duplicate IDs/keys or incompatible affected fields rather than silently erase them. Exact readback can acknowledge a write that committed before reporting an error. No cross-process locking or general autosave guarantee.

Verification: blocked create/edit and retry, stable ID/no duplicate creation, one-write full creation, stale disk/editor snapshot, no-op bytes, list order, name/icon/view/folder/smart-inclusion, preserved sections/pin/archive and unknown data. Native owned failure/retry is a separate gate from source/tests/builds. No TickTick parity claim beyond existing source semantics.

[Verification evidence](../spec/verification.md#mac-list-editor-save). Success updates the task destination but retains the existing overall app section; this correction does not introduce a Calendar-to-Tasks switch.
