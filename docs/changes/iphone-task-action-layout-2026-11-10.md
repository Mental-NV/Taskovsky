# IOS-ACTIONS-002 — Customize iPhone Task Actions

The active Tasks and Calendar parity goal authorizes a local iPhone implementation. The starting revision is `aba0b9b78a2b6af3dede10542234ba3eed0bc805`. The change extends the iPhone action mapping and [TT-027](../parity-implementation-status.md#tt-027).

TickTick describes opening Task Actions → More → Edit to pin, unpin and reorder actions. Taskovsky applies that interaction to its existing local actions. The main sheet keeps its existing action order for a new installation. Open More to reach unpinned actions and the editor. The editor has separate scrollable Pinned and More sections. Plus and minus controls move an action between sections. Native reorder grips and accessible Move earlier/later actions reorder each section. Restore Defaults restores the original order. Done applies the draft and Cancel discards it.

The layout is a device presentation preference and applies across tasks on this iPhone. It does not write workspace or settings files. Existing lifecycle checks, template availability and task revisions still govern which actions appear and whether they execute. Restore and Delete Forever remain in the Trash action sheet with the existing confirmation. Unknown saved layouts show the default actions while preserving the stored preference. A newly supported action is appended to More in an existing customized layout.

Verification uses a disposable iPhone session. It covers a changed primary order, an action moved to More, relaunch, Cancel, Reset and access to the existing commands. [Reference guide](https://help.ticktick.com/articles/7055782408586526720)

[Verification record](../spec/verification.md#iphone-task-action-layout)
