# Mobile task Move to hierarchy

## Evidence and bounded contract
D06 live reference inventory observed the task-detail list selector opening **Move to**, with Search, Inbox, current-list checkmark, lists, expandable folders, Add List and × dismiss without movement. Exact typography, row dimensions, initial expansion and new-list follow-up behavior were not verified. This implements major control/behavior similarity, not pixel-perfect parity.

| Element | Placement and wording | Behavior and data contract |
| --- | --- | --- |
| Detail list label | Existing detail header beside completion; list name + chevron | Opens frozen task/revision Move request. Uses lifecycle eligibility, so Trash/locked states remain unavailable; archived move-out remains supported. |
| Header | Inline **Move to** | Standalone row/detail route has × / accessible Close; no movement on close. Existing pushed Task Actions route retains native back navigation. |
| Search | Explicit search row with magnifying glass, **Search** prompt and Clear search | Matches active list names; matching folder reveals its active children. Search expansion is temporary and does not save folder state. The row does not replace the navigation toolbar, so Close remains available while typing. |
| Inbox | First destination row, tray | Nil list target via existing lifecycle write. Current destination has checkmark/value and is disabled. |
| Lists above/folders/below | Existing workspace placement/order | Known folder children expand/collapse locally. Current destination shows checkmark. Orphan-folder destinations remain available rather than being lost. Archived target lists excluded. |
| Add List | Plus row after destinations | Reuses existing List editor, expected-revision save, validation and dirty-cancel behavior. Enabled only while original move revision is still current. |
| Creation follow-up | Explicit footer explains close/reopen | Successful creation closes chooser **without moving task**. Reopen captures fresh revision. This avoids rebasing a stale frozen request; it is an explicit safe Taskovsky behavior, not asserted reference parity. Cancelling nested creation keeps Move open unchanged. |
| Failure | Existing lifecycle feedback | Detail and row-sheet requests retain their captured revision and reject stale moves. The pre-existing pushed Task Actions route constructs its request from the live document render; this change does not claim that route is frozen. Add List never refreshes the move request revision. Actual persistence failures remain visible; chooser stays open. |

## Implementation boundaries
`PhoneTaskSheet.swift` adds detail entry and shared hierarchical choices. `PhoneListOrganization.swift` exposes existing editor/request internally and adds optional success callback (default no-op) after its existing save succeeds. No domain mutation, recovery, schema, transaction or preference changes. Source work only at this checkpoint; parent owns native/CI and independent review.

## Required acceptance
- Detail entry and row/action entry use correct task, current checkmark and close leaves task unchanged.
- Search list/folder/no-match, expand/collapse, active target movement, Inbox and relaunch.
- Nested Add List Cancel leaves chooser/task unchanged; successful create closes chooser without moving; reopen exposes new target, actual move succeeds.
- Concurrent workspace/task change must retain stale refusal; unknown workspace/read-only/Trash guards unchanged; archived task can still move out.
- Existing row swipe and lifecycle move tests updated for title **Move to**, without dropping persistence checks.
- Neutral fixture screenshots only; no personal reference screenshots in public repository.


## Acceptance receipt
- Final production source `8b6da8b`. Coordinating parent reports final native run 3589: five regressions passed, covering search/folder/current checkmark/Close, actual move/reopen, Add List Cancel and creation without implicit movement, existing row swipe and archived move-out.
- Initial native run exposed a real issue: `.searchable` hid Close while search was active. Replaced with an explicit Search row; final regression retains Close while typing rather than weakening the assertion.
- Coordinating parent reports full **835 XCTest + 38 Swift Testing**, release and signature checks passed. Exact-head hosted CI remains a publication/merge gate.
- Stale-write rejection remains the existing expected-revision source contract; no new native concurrent-write test was performed and none is claimed.
- Actual neutral 1170×2532 Simulator screenshot inspected and retained unmodified: [D06 Move to](../assets/mobile-parity/2026-11-15/d06-move-hierarchy.png). SHA-256 `4f5639e39d9ba75db94a1f9cf923b4e8aa82e82069f3ef9a0eb30c9a3e6158a8`.
- Exact reference layout, initial expansion and creation follow-up remain unknown. Taskovsky deliberately closes after Add List without moving the task; reopen is required to capture a fresh request. No exact-parity claim.
