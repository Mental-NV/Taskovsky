# Taskvovsky

A local macOS task and notes app inspired by TickTick’s three-pane task workspace. Built with SwiftUI and Foundation, with no third-party dependencies. Requires macOS 14 or later and Swift 6 / Xcode command-line tools to build.

## Build and run

```sh
./scripts/build-app.sh
open build/Taskvovsky.app
```

You can move `build/Taskvovsky.app` into Applications. The build is signed locally; it is not a notarized distribution build.

For development, `swift run --disable-sandbox Taskvovsky`. Run the model tests with `swift test --disable-sandbox`.

## Features

- Tasks and notes with descriptions, Markdown emphasis preview, and checklists.
- Editable, colored task/note lists and tags. Drag task rows to lists or Inbox to move them.
- All Tasks, Today (including overdue), Tomorrow, Next 7 Days, Inbox, Notes, Reminders, Completed, and Trash views.
- Due dates, optional times, daily/weekday/weekly/monthly/yearly repetition, and custom reminder dates.
- Four priority levels, sorting, completed history, duplication, conversion between tasks and notes, and recoverable task deletion.
- In-app reminders with snooze and dismiss. No OS notifications or background service; check Reminders while the app is open.
- Every edit saves locally and atomically to `~/Library/Application Support/Taskvovsky/workspace.json`. An unreadable file is preserved, and save failures remain visible.

Use **⌘N** to add a task, **⇧⌘N** to add a note, and **⇧⌘L** to create a list. Press Return in the quick-add field or a checklist field to add an item. Right-click task rows, lists, or tags for actions. Click an item to edit it in the detail pane. Date changes apply with Save; Cancel leaves the schedule unchanged.

Deleting a list moves its items to Inbox. Deleting a tag removes it from items. Deleted tasks and notes remain in Trash and can be restored; there is no permanent-delete action.

Calendar tab, Eisenhower Matrix, Pomodoro, habits, countdowns, search, accounts, settings, statistics, server sync, system notifications, help, and voice dictation are intentionally excluded. No TickTick data is imported and no network requests are made.

## Layout reference

The installed TickTick app was inspected through Computer Use. Taskvovsky follows its list/tag sidebar, date-grouped rows, quick-add bar, and separate detail pane with scheduling and priority controls. This is an independent implementation of the requested subset, not a pixel-perfect clone.

## Verification

The release app builds successfully and passes local code-signature verification. Five automated tests cover JSON persistence, list/tag cleanup, trash/restore, recurrence across weekends and short months, recurring reminders, duplicate prevention after reload, normalized tag names, and unreadable-file protection/recovery.

Computer Use checks passed for launch and reload, quick task creation, descriptions and checklists, priority changes, list creation and renaming, keyboard tag creation and assignment, date/time/repeat/reminder saving, preserving time when changing the day, generating the next recurring occurrence, note editing and preview, moving notes via the list menu, dragging tasks into lists, Trash/restore, and reminder dismissal. A few sample items created during these checks remain in the local workspace.
