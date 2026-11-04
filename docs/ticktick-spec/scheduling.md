# Task scheduling and recurrence

Evidence: installed TickTick macOS app, light appearance, 2 November 2026, using a newly created disposable task in Inbox. The probe was moved to recoverable Trash afterwards. Current account settings and local time affect date, time and timezone examples below. Unless explicitly stated, labels describe controls observed, not tested downstream behavior.

## Opening and structure

The detail header has a Due Date control. Activating it opens a rounded popover with **Date / Duration** segmented modes. In Date mode the layout proceeds from a four-icon shortcut strip to a month heading, previous/current/next controls, weekday headings and a seven-column date grid; adjacent-month dates are muted. Beneath the grid are Time, Reminder and Repeat rows, followed by Clear and blue OK buttons. Current date was indicated by a blue-tinted circular background; when a time was activated the date was shown with a stronger blue fill. The precise action and hover text for all four shortcut icons need independent verification.

Activating **Time** on the undated probe selected the current date and showed a focused `00:00` time editor. A dropdown listed half-hour entries beginning `00:00`, `00:30`, `01:00`, `01:30` and `02:00`; only the visible portion was examined. A small cross at the right of the time row was visible while the menu was open. The full range, typing validation, selection and removal semantics remain untested.

The **Reminder** row opened a menu whose visible timed choices included `On time`, `5 minutes early`, `30 minutes early`, and `1 hour early`; the menu extended below the captured area, so this is not an exhaustive list. The **Repeat** row opened a menu beginning `Daily`, `Weekly (Mon)` and `Monthly (2nd)` for the current selected date; other options were obscured. A prior inspection observed an end-condition row and future occurrence highlighting, but exact rule creation, multiple reminders, end modes, DST and completion semantics need controlled experiments.

## Custom repeat editor

On 3 November, a separate disposable undated task was used to inspect Repeat. The preset menu displayed Daily, Weekly with the selected weekday, Monthly with the selected day, Yearly with the selected date, Every Weekday (Mon–Fri), and Custom. Custom opens an inline editor with a basis selector: **By Due Dates**, **By Completion Date**, or **By Specific Dates**. The first two display an `Every` numeric field and interval selector; the due-date interval menu offered Day, Week, Month and Year. Completion-date mode showed the same field and a unit menu with at least Day, Week and Month visible; the remainder was clipped and is not established.

In due-date mode, Week displayed seven weekday selectors, with the selected date's weekday highlighted in the observed initial state. Month displayed **Each / On the / Workday** segments. Each showed selectable day numbers 1–31, Last Day and a Skip Weekends checkbox; On the showed ordinal and weekday selectors; Workday offered First workday and Last workday. Year displayed **Each / On the**: Each showed a navigable month and day-number grid; On the showed month, ordinal and weekday selectors. Specific Dates displayed a navigable month grid. Selection rules, multiple selections, invalid values and holiday handling were not tested.

Confirming an annual ordinal choice in the nested editor displayed a textual rule in the outer date picker and added an **Endlessly** row. Its menu offered **Endlessly**, **End by date**, and **End by count**. The outer picker was dismissed with Escape without saving; this proves the controls and intermediate presentation, not recurrence generation or end-condition behavior. The disposable task was moved to recoverable Trash.

## Duration mode and time zones

Selecting **Duration** replaced the calendar grid with **Start** and **End** date and time fields, an **All Day** switch, a time-zone selector, Reminder and Repeat rows, and Clear/OK. The inspected initial example displayed the same current date for start and end, `00:00` start and `01:00` end, with All Day off. These values arose after opening Time and switching modes and are not established factory defaults. The time-zone control opened a nested panel offering **Fixed Time Zone** and **Floating Time**; the latter is accompanied by `When time zone changes, time remains the same.` A location/time-zone value was displayed for the fixed option. No option was committed. Validate the enabled-setting prerequisite, field ordering and date constraints, defaults when opened afresh, behavior of All Day, timezone conversion and saving/canceling before implementing this state machine.

## Taskovsky comparison (source evidence)

The Taskovsky `TaskItem` model has one optional `dueDate`, `hasDueTime` and optional `timeZoneID`, but no start/end duration fields or fixed-versus-floating mode ([model](../../Sources/TaskovskyCore/Models.swift)). Thus the reference's Duration UI and state are a confirmed feature gap, rather than a Calendar-tab difference. Taskovsky's recurrence enumeration currently supports none, daily, weekdays, weekly, monthly and yearly; an inclusive end date is stored. The inspected reference custom basis, interval, ordinal/workday, specific-date and end-count controls have no corresponding representation in that enumeration. Multiple reminder dates are represented. Generation and end-date equivalence remain unverified.

On task creation, Taskovsky recognizes a limited English pattern of relative dates and weekday names, optionally removes recognized date text, recognizes `#` tags, applies configured defaults and calculates default reminders ([TaskStore](../../Sources/TaskovskyCore/TaskStore.swift)). Completion of a recurring Taskovsky item creates at most one successor using the task's selected zone, shifts reminders, resets checklist completion, and only removes that successor on undo if it remains identical to its creation snapshot. These are implementation facts, not evidence of reference equivalence.

## Required follow-up

Inspect all shortcut tooltips and date-picker key navigation; time and reminder options including custom, multiple, all-day and timezone interactions; repeat choices and custom recurrence editor; start/end validation and overnight/multiday boundaries; save, Clear, Escape and outside-click semantics; recurrence changes, completion and Undo; timezone changes and daylight-saving transitions; and presentation at different window sizes. Measure geometry and colors in a controlled capture with known scale.
