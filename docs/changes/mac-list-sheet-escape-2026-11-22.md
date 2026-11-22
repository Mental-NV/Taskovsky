# MAC-LIST-SHEET-002 — Cancel list form with Escape

Status: candidate, macOS only. [MAC-02 and MAC-12](../mac-parity-acceptance.md#acceptance-matrix), [TT-017](../parity-implementation-status.md#tt-017), [UX-004](../spec/ui-ux.md#ux-004).

The [dated installed TickTick observation](../ticktick-spec/lists-and-tags.md#list-hierarchy-and-context-menu) showed disclosure separately from selection, Add List from a folder preselecting it, blank-name Save disabled and a Cancel with no new list. It does not establish Escape or the effect of the New Folder picker item. Labels and exact geometry are not part of this correction.

Guarded Taskovsky `1bb68b4d29a6fd0ce60a18a6b4c1319ef5698fe8` matched folder preselection and the empty-name gate at normal and minimum window sizes. Folder A disclosure hid its children without selecting the folder. Actual right-click Add List preselected A (rather than B or No folder). Explicit Cancel left list/workspace data unchanged. At 382×584, Escape with the blank name field focused did not dismiss the form.

Handle the macOS exit command on the List/Tag sheet, without intercepting window events. The explicit Cancel and save paths remain unchanged. A native open menu should consume its own first Escape. This fixes a local keyboard interaction, not verified reference Escape behavior.

## Acceptance

- On the same folder context at 382×584 and normal width, Escape from a focused name field discards blank or edited state and creates nothing. Reopen with the same preselected folder and blank name.
- With the native Folder picker open, one Escape dismisses only the picker and keeps the draft. A subsequent Escape from the form cancels it. Compare the original fixture data. Explicit Cancel still works.
- Enter a valid synthetic list name and save from the same context to verify the existing successful path; keep the test data isolated. Check a Tag form or report it separately, as it shares the sheet.
