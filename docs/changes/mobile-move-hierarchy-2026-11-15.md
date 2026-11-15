# Mobile task Move to hierarchy

## Evidence and bounded contract
D06 live reference inventory observed the task-detail list selector opening **Move to**, with Search, Inbox, current-list checkmark, lists, expandable folders, Add List and × dismiss without movement. Exact typography, row dimensions, initial expansion and new-list follow-up behavior were not verified. This implements major control/behavior similarity, not pixel-perfect parity.

| Element | Placement and wording | Behavior and data contract |
| --- | --- | --- |
| Detail list label | Existing detail header beside completion; list name + chevron | Opens frozen task/revision Move request. Uses lifecycle eligibility, so Trash/locked states remain unavailable; archived move-out remains supported. |
| Header | Inline **Move to** | Standalone row/detail route has × / accessible Close; no movement on close. Existing pushed Task Actions route retains native back navigation. |
| Search | Native searchable field, **Search** prompt | Matches active list names; matching folder reveals its active children. Search expansion is temporary and does not save folder state. |
| Inbox | First destination row, tray | Nil list target via existing lifecycle write. Current destination has checkmark/value and is disabled. |
| Lists above/folders/below | Existing workspace placement/order | Known folder children expand/collapse locally. Current destination shows checkmark. Orphan-folder destinations remain available rather than being lost. Archived target lists excluded. |
| Add List | Plus row after destinations | Reuses existing List editor, expected-revision save, validation and dirty-cancel behavior. Enabled only while original move revision is still current. |
| Creation follow-up | Explicit footer explains close/reopen | Successful creation closes chooser **without moving task**. Reopen captures fresh revision. This avoids rebasing a stale frozen request; it is an explicit safe Taskovsky behavior, not asserted reference parity. Cancelling nested creation keeps Move open unchanged. |
| Failure | Existing lifecycle feedback | Stale task move remains rejected by original revision. No automatic request refresh. Actual persistence failures remain visible; chooser stays open. |

## Implementation boundaries
`PhoneTaskSheet.swift` adds detail entry and shared hierarchical choices. `PhoneListOrganization.swift` exposes existing editor/request internally and adds optional success callback (default no-op) after its existing save succeeds. No domain mutation, recovery, schema, transaction or preference changes. Source work only at this checkpoint; parent owns native/CI and independent review.

## Required acceptance
- Detail entry and row/action entry use correct task, current checkmark and close leaves task unchanged.
- Search list/folder/no-match, expand/collapse, active target movement, Inbox and relaunch.
- Nested Add List Cancel leaves chooser/task unchanged; successful create closes chooser without moving; reopen exposes new target, actual move succeeds.
- Concurrent workspace/task change must retain stale refusal; unknown workspace/read-only/Trash guards unchanged; archived task can still move out.
- Existing row swipe and lifecycle move tests updated for title **Move to**, without dropping persistence checks.
- Neutral fixture screenshots only; no personal reference screenshots in public repository.
