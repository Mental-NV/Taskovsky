# Mac Tasks row Tags menu

Base main `7148337`; isolated branch `fix/task-row-tag-menu`.

## Gap and bounded delta

[TickTick Tasks observation](../ticktick-spec/tasks.md#active-task-context-menu) explicitly includes a Tags submenu. Taskovsky exposes tag assignment in detail but no row-menu entry. Add existing-tag assignment to the middle-panel context menu, targeting the right-clicked record even when another task is selected. Reuse current immediate assignment semantics with native checked menu choices; parent-qualified names distinguish nested tags. The actual TickTick submenu contents, geometry and dismissal behavior were not observed: this closes functional reachability only, not exact visual parity.

No tag creation/deletion/merge, schema changes, tag filtering changes, Calendar/Board/iPhone additions, or persistence redesign. Trash and archived menus remain locked. A tag removed while the menu is open or a task locked/deleted meanwhile must not be mutated. Assignment preserves all other fields and retained unknown tag IDs, and reads the current task at activation rather than a menu-opening snapshot. Parent and child tag assignment stay independent. Empty tags show a non-actionable explanation.

## Acceptance

Verify unselected-row targeting, add/remove and reopening checkmarks, parent/child labels and independent assignments, safe disappearance from an active tag filter, locked rows, empty tag state and menu dismissal without writes. Native light-theme QA, tests, release/signature, independent review and hosted CI are separate gates. No screenshot until actually captured; do not retry denied capture.

## Verification

Full native Swift suite passed (819 XCTest +38 Swift Testing) after correcting a new test initializer argument order. Release build and strict signature verification passed. Independent source review found no blocker. Hosted CI and native menu interaction checks pending; no screenshot available.
