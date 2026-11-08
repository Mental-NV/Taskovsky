# Habit: observed behavior

**Archived reference research, not Taskovsky requirements.** This module is outside the current Taskovsky baseline. Observations and unknowns below are preserved from the November 2026 investigation. See the [current parity tracker](../../parity-implementation-status.md) and [documentation index](../../README.md).


This module is outside the original Taskovsky implementation scope. The observations below were made in the installed macOS app, light appearance, on 2 November 2026. Existing account configuration affects visible data; personal habit names are omitted.

## Workspace

The Habit title dropdown switches between **Active** and **Archived**. Active shows a seven-day strip, with today's weekday and date in blue and a circular progress indicator below each date. Habit cards show an icon, title, lightning and flame counters, and seven daily check-in circles. In list layout, cards occupy full-width rows; the grid/list button switches to a two-column card layout at the observed window size. Switching it again restored the original layout. No resize thresholds were measured.

Selecting a card outlines it in blue and displays a detail pane with four cards: **Monthly check-ins**, **Total check-ins**, **Monthly check-in rate**, and **Streak**. Beneath them are a month calendar with previous/next navigation and a Habit Log. A streak control is present, but its alternate state was not inspected. When no card is selected, the detail pane shows a faint illustration.

The workspace overflow offers **Settings** and **Export**. Habit Settings contains a switch labeled `Show in "Today" & "Next 7 days"`, plus Cancel and OK; it was on in the observed account and was not changed. Export behavior was not tested.

## Creating and checking in

The plus button opens **Create Habit**, with an icon editor, name, Frequency, Goal, Start Date, Goal Days, Section, Reminder and an **Auto pop-up of habit log** switch. The observed initial values were Every day, Achieve it all, the current date, Forever, Others and an off log switch. Frequency has Daily, Weekly and Interval tabs. Goal offers Achieve it all or Reach a certain amount; the latter exposes quantity settings. These are observed account values and controls, not a verified complete set of defaults or rules.

An assistant-created daily habit was saved. It appeared at the top of the active list. Clicking its current-day circle changed the circle to blue with a white checkmark and increased its row counters from zero to one day. The date strip showed a partial blue progress arc. Selecting the habit showed one monthly check-in, one total check-in, a one-day streak, a 3% monthly rate and a checked date in its detail calendar. The formula for the rate and behavior with other frequencies were not established.

Right-clicking the checked circle offered **Habit Log** and **Reset**. Habit Log opened a dialog with the habit icon/name, date, five mood faces, a multiline note field and Cancel/Save. A test note saved there appeared in the detail pane's Habit Log with its date and selected mood icon. Reset was not exercised; its effects on a saved note are unknown.

## Archive and menus

The selected habit's detail overflow offered **Edit**, **Checked-in Style** (submenu indicated), **Archive** and **Delete**. The submenu contents and deletion behavior were not established. Archiving the disposable habit removed it from the active list, cleared the detail pane, and showed a transient **Archived** toast. The archived screen showed its card and preserved its two one-day counters. Right-clicking that card offered **Pick up habit** and **Delete**; neither was invoked. The disposable probe remains archived, rather than being permanently deleted.

## Remaining evidence

Inspect every frequency and goal editor, validation, reminders, past and future check-ins, Reset and its effect on logs, check-in style choices, archive restoration, edit, sections, export, statistics definitions, keyboard and hover states, persistence, responsive thresholds, colors and motion. Verify destructive actions without permanently deleting data.
