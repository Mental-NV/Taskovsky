# Keep the Mac Calendar day sheet open as overflow changes

Scope: local Month and Multi-Week, [MAC-18](../mac-parity-acceptance.md#acceptance-matrix) and [UX-017](../spec/ui-ux.md#ux-017).

## Reproduction and reference limits

In guarded native Taskovsky on the product source in main `c1ab23f`, with Show Completed off and a day at `+1 more`, completing the hidden task caused the date sheet to disappear. Resizing the window subsequently reopened that date sheet without clicking overflow. The dated TickTick observation establishes multi-day bars in Week, not the Month/Multi-Week overflow lifecycle. This is a local presentation fix, not a claimed TickTick interaction match.

## Contract and acceptance

Keep the date sheet attached to the day cell, independent of whether the `+N more` button is visible. Keep the same date, live visible items, existing completion and schedule callbacks, Done and Escape. Show only the same overflow button when there are hidden entries. No changes to calendar layout, projection, persistence, dates, or iPhone.

Verify on an exact native Mac build: open a synthetic day at `+1 more`, complete its hidden task with Show Completed off, and confirm the sheet stays on that date with the remaining items. Dismiss it once explicitly, then resize until the day overflows again and confirm it does not reopen on its own. Open a separate crowded day and dismiss with Escape with no writes. Exact-head hosted checks and independent review are separate acceptance gates.
