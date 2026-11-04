# Other modules: initial reference observations

These screens are included in the reference inventory, not the authorized Taskovsky implementation scope. The following records only the states actually viewed; comprehensive behavior remains outstanding.

## Calendar

The month view shows a title with month and year, add button, view selector, previous/Today/next segmented navigation and an ellipsis. A seven-column grid has weekday headers, date numbers and colored event/task bars. The current date has a blue circular number and its day column a light tint. An entry may show a checkbox or recurring symbol and a right-aligned time; multi-day entries can span columns. Adjacent-month dates are muted. The view menu listed **Day** (`D/1`), **Week** (`W/2`), **Month** (`M/3`), **Year** (`Y/4`), **Agenda** (`A/5`), **Multi-Day** (`5 Days`) and **Multi-Week** (`2 Weeks`); Month had a checkmark. These labels alone do not prove keyboard shortcut behavior.

Selecting Day showed a single day column, an all-day region, a timezone label and an hourly vertical timeline with a current-time line. The time grid was scrolled near the current hour. The content and controls of the remaining views, creation, editing, dragging, scrolling, overflow and calendar settings remain unverified.

## Eisenhower Matrix

The observed screen used four large rounded white panels in a two-by-two grid on a pale background. Quadrant labels and numbered circular icons were red for **Urgent & Important**, orange for **Not Urgent & Important**, blue for **Urgent & Unimportant**, and green for **Not Urgent & Unimportant**. Each panel independently contained scrollable task rows and expandable group headers such as Overdue or Completed. A controlled priority probe and completed-visibility test are documented in [Eisenhower Matrix](eisenhower-matrix.md); broader inclusion rules and gestures remain unverified.

## Pomodoro

The screen title was **Pomodoro**, with **Active / Archived** segmented navigation, plus and ellipsis controls. The central list displayed named focus targets, accumulated duration and a play icon. A fixed bottom strip displayed `Pomo`, `25:00`, play and stop controls. A right pane contained an Overview with Today's Pomos, Today's Focus, Total Pomos and Total Focus Duration cards, followed by a dated Focus Record with a plus and ellipsis. A short start/pause/stop probe, timer creation and settings were subsequently inspected; see [Pomodoro and focus](focus.md) for observations and remaining unknowns.

## Habit

The initial screen showed a Habit heading with a dropdown, grid, add and ellipsis controls. A seven-day strip displayed weekday/date labels and circles. Each habit card contained an icon, name, two counters and seven aligned daily circles; an unselected detail pane displayed a faint illustration. A subsequent disposable-habit probe covered check-in, a log, detail statistics and archive; see [Habit](habit.md).

The plus opens a separate **Create Habit** dialog. The observed initial fields were an icon picker, a name placeholder `Daily Check-in`, Frequency `Every day`, Goal `Achieve it all`, Start Date (the current date), Goal Days `Forever`, Section `Others`, a Reminder add button, and an off **Auto pop-up of habit log** switch; Cancel and blue OK appear at the bottom. Frequency opens a popover with Daily, Weekly and Interval tabs, weekday selection and Cancel/OK. Goal offers `Achieve it all` or `Reach a certain amount`; selecting the latter enables a quantity control. Its nested editor showed Daily quantity, unit `Count`, `When checking` set to `Auto`, and `Record(Count)` set to 1, with Cancel/OK. The unsaved dialog was canceled. The options' resulting data and behavior, other tabs, validations and reminders remain unverified.

## Countdown

The Countdown screen showed a heading/dropdown and add/ellipsis controls. Its cards displayed an icon and title, a large blue number, and a muted `Days until` or `Days since` date. A subsequent probe established its two-stage editor, selected menus and archive flow; see [Countdown](countdown.md). Other types, date edge cases and responsive layout remain to be tested.
