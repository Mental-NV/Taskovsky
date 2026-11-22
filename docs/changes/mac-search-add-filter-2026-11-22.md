# MAC-SEARCH-FILTER-001 — Match the Add Filter handoff from Search

Mac Full Search, [MAC-11](../mac-parity-acceptance.md#acceptance-matrix), [TT-024](../parity-implementation-status.md#tt-024), [UX-011](../spec/ui-ux.md#ux-011).

The [November 2 live TickTick observation](../ticktick-spec/search-and-filters.md#add-filter-dialog) saw Search → Save as filter open “Add Filter” with blank required name, disabled Save, Normal/Advanced, and the query in “Include.” In a guarded Taskovsky baseline using the same current Search and FilterEditor code, the sheet was “New Filter,” duplicated the query into the name and “Keyword,” and enabled Save immediately. Its applied Uncompleted criterion transferred correctly. TickTick filter-save or predicate semantics were not exercised in the reference.

For that entry only, start with a blank name, title the sheet “Add Filter,” and label the retained query “Include.” Keep all criteria transfer, validation, Cancel, acknowledged Save, other New/Edit Filter entry points, and iPhone behavior unchanged. Do not add reference-only controls with no Taskovsky behavior.

## Acceptance

From Full Search with a neutral query and an applied criterion, open Save as Filter. Verify blank name/disabled Save, Include query and visible active criterion; Cancel writes nothing and leaves Search intact. Reopen, name one synthetic filter, check Save enables and assert exact stored keyword/criteria. Sidebar New/Edit remain unchanged. Any non-reference save verification is Taskovsky-only; geometric fidelity remains separately measured.
