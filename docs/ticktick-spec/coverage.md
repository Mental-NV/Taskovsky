# TickTick research coverage

This is a dated research-coverage ledger from the November 2026 reference inspection, not a current Taskovsky status list. “Partial” means the reference still needs experiments; “not inspected” includes visible controls that were not exercised. The [dedicated parity tracker](../parity-implementation-status.md) owns all current Taskovsky implementation status and scope.

| Surface | TickTick inspection | Next evidence needed |
| --- | --- | --- |
| Navigation rail and task workspace | Partial: shell, several smart lists, selection, task/note details | Every icon, hover, keyboard focus, sizes and resize thresholds |
| Lists, folders, sections, tags, filters | Partial: folder/list/tag menus and list/tag editors inspected | Save effects, ordering, drag/drop, merge, archive, permissions and filter edge cases; [details](lists-and-tags.md) |
| Tasks, notes, subtasks, priorities | Partial: task context menu, pinning, child detail and parent completion observed | Full editing and conversion state machines, hierarchy, keyboard actions and recurrence edge cases; [details](tasks.md) |
| Scheduling, reminders and repetition | Partial: Date/Duration, timezone choices and custom repeat editor/end choices observed | Rule generation, end-condition effects, validation, timezone and reminder edge cases; [details](scheduling.md) |
| Completion, Won't Do, Trash | Partial: completion and Trash feedback, Restore and Delete Forever menu entries observed | Multiple simultaneous operations, repeat occurrences, full deleted-item context behavior and permanent-delete confirmation in reference |
| Search | Partial: quick/full search, range/status/list/tag controls and Add Filter modes inspected | Cloud and deleted results, result actions, saved expression semantics, filter combinations and keyboard interactions; [details](search-and-filters.md) |
| Settings | Partial: Smart Lists, Date & Time, More and About selected for Taskovsky | All reference tabs and controls, defaults, persistence, side effects and disabled states |
| Calendar | Partial: seven modes, sidebar, add entry, options and November 8 Arrange/undated-task experiments; resource extract corroborates structure | Navigation increments, item interactions, gestures, filters, all settings and resize behavior; [details](calendar.md) |
| Eisenhower Matrix | Partial: four priority mappings, task context menu and completed visibility tested | Inclusion rules, task completion, drag/drop, persistence and responsive geometry; [details](../archive/ticktick-modules/eisenhower-matrix.md) |
| Pomodoro / focus | Partial: short timer lifecycle, settings, timer and record dialogs, association chooser and record batch controls | Full sessions and breaks, stopwatch, persistence, editing, archives, record operations and geometry; [details](../archive/ticktick-modules/focus.md) |
| Habit | Partial: creation, one daily check-in, note, statistics, settings, layout and archive observed | Frequency/goal rules, reset, edit, archive restore, statistics semantics and geometry; [details](../archive/ticktick-modules/habit.md) |
| Countdown | Partial: add and style steps, selected repeat/reminder options, notes dialog, card context menus and archive | Other types, custom rules, restore, grouping, persistence and responsive geometry; [details](../archive/ticktick-modules/countdown.md) |
| Accounts, sync, notifications, help, statistics | Not inspected comprehensively | Catalog visible states and interactions without changing credentials or transmitting data |
| Common visual system and resizing | Partial: initial settings-window capture measurements and JPEG pixel samples | Lossless colors, font metrics, other components and states, pixel/point conversion, resize ranges and animation timing; [measurements](design-measurements.md) |

## Historical Trash observations

TickTick's deleted-row context menu showed **Restore** and **Delete Forever**. Restore returned an assistant-owned disposable task to its original Inbox, removed it from Trash, left the Trash view open and displayed a transient `Restored to "Inbox"` toast with a right chevron. The chevron's destination was not established. Moving the probe back to Trash produced `Task deleted` with an orange Undo arrow. Permanent deletion was not executed.

The original report also recorded historical Taskovsky live checks on a separate disposable task (not repeated for the source baseline): Move to Trash produced the dark `Task deleted` toast with Undo; it was absent after a six-second wait. Undo returned the task to its list. Both the Trash detail button and row context menu restored the probe to Inbox with a `Restored to "Inbox"` toast; the toast chevron navigated to Inbox. The context menu's Delete Forever opened a confirmation explaining that deletion cannot be undone; Cancel preserved the task. The probe was subsequently moved back to recoverable Trash. Automated test counts reported in the implementation status need to be re-run or linked to an authoritative result before being treated as current evidence.

