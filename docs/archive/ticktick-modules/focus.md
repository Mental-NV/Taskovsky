# Pomodoro and focus: observed behavior

**Archived reference research, not Taskovsky requirements.** This module is outside the current Taskovsky baseline. Observations and unknowns below are preserved from the November 2026 investigation. See the [current parity tracker](../../parity-implementation-status.md) and [documentation index](../../README.md).


This reference module is outside the original Taskovsky implementation scope. Observations are from the installed macOS app in light appearance on 2 November 2026; account configuration and existing records can affect the screen. Personal timer and task names are omitted.

## Workspace and timers

The **Pomodoro** workspace has an Active / Archived segmented control, a plus button, an overflow menu, a central timer list, a bottom timer strip, and a right-hand overview or selected-timer detail. Timer rows show an icon, name, accumulated duration and a play button. Selecting a timer shows its name and mode, Focused Days, Today's Focus and Total Focus cards, a period selector and a chart. Its detail overflow offers **Edit**, **Add Record**, **Archive**, and **Delete**. The main overflow offers **Full-Screen Mode**, **Statistics**, and **Focus Settings**. Their effects were not all exercised.

The observed Archived empty state says “No archived timers” and explains that timers can be archived and restored later. Archiving and restoring a timer were not tested.

## Timer lifecycle

The bottom strip showed a 25:00 Pomo with a play control and the prompt “What would you like to do?”. Starting the timer counted down; pausing changed the strip to **Paused** with play and stop controls. Stopping this short, approximately six-second probe reset the strip to 25:00 without a confirmation, and no new record appeared in the observed overview. This does not establish what happens after a longer session, completion, or a break. A timer was not left running.

## Creation and association

The plus button opens **Add Timer** with an icon editor, name field, link control, **Pomo** and **Stopwatch** modes, and an editable Pomo duration initially showing 25 minutes in this account. Selecting Stopwatch disabled the duration field. The link control opens a chooser with **Recent**, **Task**, and **Habit** tabs, a search field and grouped results. The dialog was canceled; saving, validation and link semantics remain unverified.

The overview's Focus Record plus opens **Add Focus Record** with a task selector, start and end time selectors, a type field showing `Pomo: 0 Pomos` in the empty state, and a Focus Note area. Save was disabled in that empty state. The start time selector opens a calendar/time picker with Cancel and OK. The record dialog was canceled without saving.

The Focus Record overflow contains **Batch Management** and **Delete All**. Batch Management displays Date, Duration and Linked Status filters, date-group and record checkboxes, and Select All. The Date filter offered All, Today, Yesterday, This Week, Last Week, This Month, Last Month and Custom. Selection, filtering results and deletion were not exercised; Delete All was not invoked.

## Settings

**Focus Settings** showed Sync Across Devices with a Premium marker; Pomo Duration, Short Break Duration, Long Break Duration and Pomos per long break numeric fields; and Auto-Start switches for **Next Pomo** and **Break**. The observed account values were 25, 5, 15 and 4 respectively, with both auto-start switches off. These are observed values, not verified factory defaults. No setting was changed.

## Remaining evidence

Inspect full-screen and statistics, timer editing and validation, archive/restore, all association and record filters, manual record save/edit, complete session and break transitions, stopwatch, sound, keyboard/hover states, persistence, accessibility, geometry and resizing. Verify destructive-action confirmation without permanently deleting user data.
