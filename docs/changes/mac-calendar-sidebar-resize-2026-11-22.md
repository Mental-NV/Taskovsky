# MAC-CALENDAR-SIDEBAR-001 — Preserve Calendar sidebar browsing on resize

Status: candidate for [MAC-15](../mac-parity-acceptance.md#acceptance-matrix), based on `4670c38ee5f211bcf642347dd4b66dd4135c4d5d`. macOS only, [TT-033](../parity-implementation-status.md#tt-033) and [UX-017](../spec/ui-ux.md#ux-017).

## Evidence and intended behavior

Guarded Taskovsky with the identical baseline product tree reproduced a state reset: at a 964-point Week window, Previous Month browsed from November to October without changing the November 16–22 grid, and expanding Lists exposed Inbox. At 780 points, reopening the compact sidebar reset the month to November and collapsed Lists. Widening to 964 reset them again. The grid focus and All scope remained unchanged throughout.

The docked and compact sidebars are distinct SwiftUI views. Hold the browsed month override and Lists/Tags disclosure in their shared Calendar workspace. Use the focus month when no manual browse override exists and reset the override when the grid focus changes. No changes to sidebar geometry, mode, source filters, scope persistence, iPhone, or settings schema. Browsing/disclosure remain session-local and are not saved across relaunch. Existing [dated reference evidence](../ticktick-spec/calendar.md#sidebar-and-creation) establishes the miniature month and lists/tags disclosure. The exact TickTick resize transition was not freshly observed, so this fixes lost local interaction state, not a claimed exact match.

## Acceptance

- Docked Week: browse to an adjacent month and expand Lists and Tags using neutral fixtures. Verify the main Week focus and filters are unchanged.
- Narrow, reopen the sidebar, widen, and check the same browsed month and both disclosure groups remain. The compact sidebar stays closed on auto-transition until explicitly reopened.
- Select a new mini-month date or use Today and check the main view and sidebar month follow the new focus. Existing source All/reset and disclosure transitions continue to work with no task mutations. Keep native evidence separate from CI and any separately authorized reference comparison.
