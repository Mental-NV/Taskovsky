# Taskovsky

A local macOS task and notes app inspired by TickTick’s three-pane task workspace. Built with SwiftUI and Foundation, with no third-party dependencies. Requires macOS 14 or later and Swift 6 / Xcode command-line tools to build.

## Build and run

```sh
./scripts/build-app.sh
open build/Taskovsky.app
```

You can move `build/Taskovsky.app` into Applications. The build is signed locally; it is not a notarized distribution build.

For development, `swift run --disable-sandbox Taskovsky`. Run the model tests with `swift test --disable-sandbox`.

## Features

- Tasks and notes with plain-text descriptions and checklists. Notes live inside lists; date grouping has a Note section and there is no separate Notes tab.
- Editable, colored task/note lists and tags. Drag task rows to lists or Inbox to move them; drag lists to reorder them. A persisted Manual sort follows your stored order with in-row above/below insertion indicators; other sorts compute their order and reject drops.
- Configurable All, Today (including overdue), Tomorrow, Next 7 Days, Inbox, Summary, Completed, Won't Do, and Trash smart lists.
- Due dates, optional times, daily/weekday/weekly/monthly/yearly repetition, an inclusive recurrence end date, previews of repeating days, multiple custom reminders, and multiple timed/all-day reminder defaults.
- Four priority levels, sorting, completed history, duplication, conversion between tasks and notes, and recoverable task deletion.
- Search tasks, notes, lists, tags, and saved filters with highlighted matches, relevant snippets, keyboard navigation, and separate completion actions. Press Return in quick search for full results with date/list/tag/status criteria, then save those criteria as a filter.
- Local editable plain-text summaries with period/list/status filters, grouping, field selection, next-period tasks, Copy, and Save as Note.
- Settings (⌘,) for smart-list visibility, week start, week numbers, scheduling time zones, recognition, task defaults, templates, and About.
- Live date highlighting, date recognition preview with an ignore action, tag suggestions, and Shift-Return descriptions during quick entry. Double-click a row title to rename it inline. Date/time and #tag recognition during quick entry. Optional URL-only title parsing fetches the page title; disable it in Settings to keep URLs unchanged.
- Built-in and custom templates, a template gallery, and saving an existing task as a template.
- A five-second completion Undo message and a completion chime. Undoing completion safely handles the next recurring occurrence.
- Resizable task/detail panes, an animated collapsible list sidebar, collapsible Lists/Filters/Tags sections, saved panel sizes, and list symbols or emoji. Task-row metadata hides as whole items at narrow widths, with optional body preview and checklist rows from the More menu. Narrow windows switch the detail to a 300pt overlay drawer (Side peek) or a separate pop-up window (View Options); wide windows dock it. Very narrow windows auto-hide the sidebar (manual preference remembered, toggle reveals an in-window navigation overlay) down to the live-verified 382x580 minimum (382x552 content floor plus native chrome).
- In-app reminders with snooze and dismiss. No OS notifications or background service; check Reminders while the app is open.
- Every edit saves locally and atomically to `~/Library/Application Support/Taskovsky/workspace.json`; preferences save beside it in `settings.json`. An unreadable file is preserved, and save failures remain visible. Existing workspaces migrate without losing tasks. The app automatically migrates data and preferences from the previous misspelled app name on first launch.

Use **⌘N** to add a task, **⇧⌘N** to add a note, and **⇧⌘L** to create a list. Press Return in the quick-add field or a checklist field to add an item. Right-click task rows, lists, or tags for actions. Click an item to edit it in the detail pane. Date changes apply with OK; Escape or closing the popover leaves the schedule unchanged. Clear removes the schedule.

Deleting a list moves its items to Inbox. Deleting a tag removes it from items. Deleted tasks and notes remain in Trash and can be restored; an individual trashed item can also be permanently deleted via its context menu, footer, or detail banner after an explicit cannot-be-undone confirmation. There is no Empty Trash or bulk purge.

Calendar tab, Eisenhower Matrix, Pomodoro, habits, countdowns, accounts, statistics, server sync, system notifications, help, voice dictation, and rich text formatting are intentionally excluded. No TickTick data is imported. URL-title recognition is the only network feature; tasks and settings stay on this Mac.

## Layout reference

The installed TickTick app was inspected through Computer Use. Taskovsky follows its list/tag sidebar, date-grouped rows, quick-add bar, and separate detail pane with scheduling and priority controls. This is an independent implementation of the requested subset, not a pixel-perfect clone.

## Verification

The release app builds successfully and passes local code-signature verification. Sixty-nine automated tests cover app-name data and preference migration, JSON persistence, legacy migration, settings/templates/filters, recognition and defaults, list/tag cleanup, trash/restore, recurrence across weekends, short months and daylight-saving changes, recurring reminders, duplicate prevention, completion undo, normalized tag names, unreadable-file protection/recovery, responsive layout geometry, monotonic collapse sweeps, dock boundaries and dock-safe drag clamps, collapse transitions and panel-drag math, drop-batch aggregation and insertion-edge rules, detail selection-state transitions, day-relative date boundaries including today-time-only rows, single-consume shared completion Undo, atomic task moves with timestamp-preserving no-ops and task/list reordering with rejection and legacy-file cases, trash/undo exact field preservation, restore of completed/Won't Do/notes with original or missing lists, guarded single-record permanent delete, and recurrence-safe restore.

Computer Use checks cover launch and reload, quick creation, descriptions and checklists, priorities, list editing, tags, date/time/repeat/reminder saving, notes, task moves, Trash/restore, smart-list visibility, date-picker options, recognition/default effects, completion Undo, Won't Do/reopen, search and saved filters. A few sample items created during these checks remain in the local workspace.
