# MAC-TASK-ROW-001 — Put active-task priorities in the first context-menu level

Status: candidate for [MAC-04](../mac-parity-acceptance.md#acceptance-matrix), Mac only. See [TT-021](../parity-implementation-status.md#tt-021).

The [dated installed TickTick observation](../ticktick-spec/tasks.md#active-task-context-menu) showed a red/orange/blue/outline flag palette at the top level on an active, undated Inbox task. Its Date shortcut effects, priority action outcomes, and context menus for other task states were not established.

Native Taskovsky on the Tasks code in `91f1dc9567d2ae330447bf1b0a6fc36c3a21e02a` at 1060×700 and minimum 382×584 exposed the priorities only within a submenu. Selecting High worked, changed just the target priority and updated timestamp, and retained selected detail.

Use a [native SwiftUI menu palette](https://developer.apple.com/documentation/swiftui/controlgroupstyle/palette) for active task rows, in High/Medium/Low/No priority order. The same local labels, colors and existing update action apply; no new custom menu, Date shortcuts, scheduling or persisted rule. Keep the existing submenu for notes and history, and existing restricted archived/deleted actions. The observation establishes the direct flag strip, not exact color/geometry, modern native rendering or keyboard parity.

## Acceptance

- Native right-click the same neutral row at 1060×700 and 382×584. Check first-level four separate actions/icons and all existing neighbor controls. Validate actual pointer and available keyboard or AX path; record untested paths.
- Select one level, verify exact title/detail and only target priority + timestamp. Reopen and reset to No priority. Notes/history remain on their current path and no unrelated data changes.
- If the native palette does not expose actionable names or render a usable direct row, retain the functional baseline instead of rebuilding the menu.
