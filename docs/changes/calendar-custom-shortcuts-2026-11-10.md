# CAL-NAV-002 — Customize the Mac Calendar shortcuts

The active local Tasks and Calendar parity goal authorizes this Mac change. It updates UX-017 and TT-033. TickTick's June 2026 changelog documents customizable shortcuts for opening the Calendar date picker and showing or hiding Calendar beside Tasks. The reference's exact bindings and recording UI remain unverified. [TickTick changelog](https://ticktick.com/public/changelog/en.html).

Settings → Shortcuts lets users record or clear Jump to Date and Toggle Calendar Beside Tasks, and restore defaults. The date-jump default stays Shift-Command-J. The split starts unassigned. Taskovsky accepts a letter with Command and at least one other modifier. It rejects duplicate bindings and chords assigned to existing app menus or the established editing and creation commands. During recording, Escape or leaving Settings cancels. A rejected chord leaves the last saved binding intact and keeps the recorder open.

The assigned chords appear on their View menu actions and update in the running app. Jump to Date is available when Calendar is visible and its picker or editor is closed. The split command is available from the main workspace and uses the same toggle as the Tasks context menu. An assigned command stays within Taskovsky. Preferences live in the local Mac defaults suite and do not modify task or Calendar settings files.

Verify recording, conflicts, Escape, live menu dispatch, clearing, defaults, persistence after relaunch, and that a chord cannot open an editor in another window. The existing iPhone layout and settings remain outside this Mac interaction change.

[Mac verification record](../spec/verification.md#calendar-custom-shortcuts).
