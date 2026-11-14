# Mobile Calendar header hierarchy — November 14, 2026

## Observed scope

Live inventory C01/C02 puts the mode chooser at Calendar's leading edge; C04 starts overflow with Filter View Range, View Options and Arrange Tasks. Taskovsky used the workspace drawer at the leading edge, a trailing mode chooser and separate filter icon. This slice moves existing controls into the observed hierarchy. Tasks/Search retain their drawer. Existing month Jump to Date, modes, preference transactions and calendar scheduling remain unchanged.

This is partial structural parity only. The reference trailing calendar overview (C03), existing Day/Week/Month/Year/Agenda/Multi-Day/Multi-Week names and ordering versus reference List/Year/Month/Week/3 Day/Day, month-label behavior, overview geometry, Calendar arrangement side panel and external actions remain outside this slice. Do not add inert Subscription/Share/Print entries or imply existing Jump to Date is the reference overview. No grid/data/persistence behavior changes.

## Acceptance

Full tests, release/signature, independent review, native header/menu geometry, filter Cancel/save/reopen/reset and distant-date jump are required. Inspect actual light-theme screenshots. Original worktrees and user QA device remain untouched. Exact hosted CI must pass before merge; no calibrated pixel or physical-device parity claim.
