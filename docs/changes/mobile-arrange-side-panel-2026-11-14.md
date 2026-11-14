# Mobile Calendar Arrange side panel — November 14, 2026

## Reference and scope

Read-only TickTick iPhone Mirroring observation in existing Taskovsky Codex turn `01a1dc45-9ba2-74a3-a850-57bd35008e04`: Calendar Arrange opens a full-height right panel covering approximately 72% of that captured phone viewport; gutter and first day column remain exposed. Empty exposed-grid tap closes it. Group choices sit below the title, overflow at top right, Filter at bottom with centered dialog. Filter Cancel preserved selection; starting Today was restored, Computer Use stopped, no data changed. Drag behavior was not observed and other viewport sizes are untested.

This slice changes the existing Taskovsky Arrange container from a bottom sheet to a trailing panel using approximate 0.72 viewport width capped 420 pt as an implementation choice, not a reference threshold. Existing grouping/list/overdue controls, task scheduling and nested task details are retained. Matching top grouping controls and bottom Filter/overflow is separate work, not claimed here.

## Interaction safeguards

No full-screen hit-testable backdrop and no disabled Calendar wrapper: exposed date/time drop targets must remain usable. Underlying tap/open/edit/complete/create callbacks dismiss the panel instead of performing an action while it was open; drops and existing-card move/resize remain guarded by existing session/revision rules; folded-hour gestures also remain active. Done uses an explicit close callback, nested editors retain their own sheets, and one root occurrence-scope dialog serves recurring drops. Leaving the Calendar tab closes the panel.

## Acceptance gates

Full suite, release/signature, independent source review and exact CI; owned native side-panel geometry/dismissal without task creation/opening, nested edit/Cancel, actual hour/all-day/Month/Multi-Week drops, Undo, recurring-drop Cancel/occurrence/series. Inspect real normal light-theme screenshots. Existing accessibility support retained, no accessibility-layout polish. Do not merge if drag/drop or scope presentation regresses. Original user worktrees, fixtures and devices preserved. No full Calendar or pixel-perfect claim.
