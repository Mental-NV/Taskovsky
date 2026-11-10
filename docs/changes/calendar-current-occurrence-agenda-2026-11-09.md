# CAL-OCCURRENCE-001 and CAL-AGENDA-001

## This occurrence and Series

A scheduled repeating task without a saved successor offers **This occurrence** and **Series** in Calendar. Dragging or resizing a recurring card stages the same choice. Cancel leaves the task unchanged. Nonrepeating cards use the existing scheduling path. Projected future cards remain read-only. On iPhone the visible timed resize handle is a named control. Dragging moves the end, and tapping opens the staged resize editor.

The first occurrence-only edit saves the original date, time mode, duration and reminder provenance alongside the displayed schedule. Subsequent occurrence-only moves reuse that baseline. Forecasts and completion successors use the baseline and keep the saved recurrence anchors and position. Completion-based rules use the actual completion time. The successor starts without an exception, and a parent's moved occurrence does not shift the relative schedule of its successor subtree.

A current card and a forecast can share an instant and still have separate identities. Reopening a previous record while its saved successor survives does not create duplicate forecasts or make the previous record the current occurrence. Explicit series schedule changes clear the exception. A reminder-only edit affects the visible occurrence. Copies keep the displayed date and omit the source occurrence baseline.

Undo restores only schedule fields. After relaunch, **Restore original schedule** stages the baseline for explicit Save or Done. Workspaces without exceptions use the existing task array. While an exception remains, the file uses a typed task collection. Older builds require an array and enter their recovery state while retaining the file. The current Mac writer also refuses a protected file with unrecognized content. Restoring the last exception returns the file to its earlier collection shape.

The [TickTick recurrence guide](https://help.ticktick.com/articles/7055782206349770752) documents a one-occurrence choice. The [FAQ](https://help.ticktick.com/articles/7055792921664028672) describes future cycles as read-only while the current one is active. Taskovsky owns the storage, overlap and successor rules above.

## Agenda Show more

Agenda starts with 30 local days. **Show more** appends six local calendar months without shifting the start or changing sources. The footer shows the last visible day. The view accepts up to four extensions per starting window. Today, previous or next period, and leaving Agenda reset the extension. The horizon is view state and writes no task data or preference. An empty Agenda still exposes Show more.

The [installed Mac audit](../calendar-visual-parity-audit-2026-11-08.md) observed a six-month extension. The starting horizon and cap are Taskovsky choices. [TickTick Agenda guide](https://help.ticktick.com/articles/7213444784319365120).

## Mac Calendar mode shortcuts

In the active Mac Calendar window, 1 opens Day, 2 Week, 3 Month, 4 Year and 5 Agenda. The selector displays these keys, and the selected mode uses its ordinary saved preference. Typing in a task title, date editor or other view follows the usual text and control handling. Modifiers and held repeats are outside the shortcut mapping. The [letter shortcut follow-up](calendar-letter-shortcuts-2026-11-10.md) adds D, W, M, Y and A to the same mode commands.

[Verification record](../spec/verification.md#calendar-current-occurrence-agenda).
