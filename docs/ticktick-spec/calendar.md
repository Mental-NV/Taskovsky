# Calendar module

Reference: installed TickTick macOS app, light appearance, 2 November 2026. The separate Calendar module is excluded from Taskovsky's original implementation scope, but included here to document the reference product. Displayed dates, events, colors and visible options depend on account settings and data. No existing event was modified; an empty add editor was dismissed without entering content. The previously selected Day view was restored after inspection.

## Shell and view selection

The main header has a sidebar toggle, month/year title, plus button, view selector, segmented previous/Today/next controls and ellipsis. The selector lists Day (`D/1`), Week (`W/2`), Month (`M/3`), Year (`Y/4`), Agenda (`A/5`), Multi-Day (`5 Days`) and Multi-Week (`2 Weeks`); the current selection has a blue check. These labels are displayed shortcuts, not independently tested keybindings. Choosing Multi-Day changed the selector label to `5 Days`; Multi-Week changed it to `2 Weeks`. The available customization of those counts remains untested.

| View | Observed structure |
| --- | --- |
| Day | One day column with weekday/date header, all-day area, time-zone label, scrollable hourly grid and a red current-time line. |
| Week | Seven weekday columns with an all-day strip above a vertically scrollable time grid. Timed entries appear at their times; all-day or multi-day bars occupy the strip. In the inspected account the visible week ran Sunday–Saturday. |
| Month | Seven-column month grid with weekday headers, date numbers, colored compact task/event bars, a blue current-date circle and a pale current-day background. Neighboring-month dates are muted. |
| Year | Twelve miniature month calendars in a four-column by three-row grid at the captured window size. Dates have different pale-blue fills, and the current date has a strong blue fill. The meaning and scaling of the fill intensity have not been verified. Clicking the current date returned to the previously selected Week view, focused on the corresponding week. |
| Agenda | Vertically scrolling date groups with day number/weekday, a time column and colored event cards with a narrow colored leading edge. The observed empty current day displayed an illustrated `No tasks today` banner. A multi-day event appeared in each applicable date group. Some accessibility labels and visible recurring-event date ranges looked inconsistent; do not treat those strings as a validated recurrence algorithm. |
| Multi-Day | In the observed configuration, five adjacent date columns shared the hourly-grid and all-day-strip layout. |
| Multi-Week | In the observed configuration, two rows of seven day cells filled the main area, using the same compact colored bar style as Month. |

The title and navigation update as views change. Previous/next increments, start-of-week behavior, selected-date persistence, overflow, drag/drop and keyboard handling require controlled testing.

## Sidebar and creation

The header sidebar toggle revealed a left pane containing a miniature month grid, month navigation arrows/current-date control, blue dots on some dates, a band marking the displayed two weeks, and a selected current date. Below it were All, Lists, Tags and Calendar Subscription selectors; the latter three had disclosure controls, and All was checked. The meaning of dots and filter combination behavior were not tested. Toggling the sidebar again hid it and returned width to the calendar.

The plus button in the observed two-week view opened a floating blank task editor, prefilled visually with the current date and Inbox, with title placeholder `What would you like to do?`, body placeholder `Write something or type / for commands`, priority flag, list control and more menu. Clicking outside dismissed the empty editor. No title was entered, and whether a blank record was persisted was not independently established. Creating by clicking or dragging on a date/time grid, all-day versus timed defaults and saving flows remain unverified.

## View options

The header ellipsis in Agenda offered **View Options**, **Arrange tasks**, and **Calendar Subscription**. View Options opened a separate dialog containing **Color** and **Style** links, switches for **Show Completed**, **Show Checklist Item**, **Show All Repeat Cycles**, **Show Habit**, **Show Focus Records**, **Show Countdown**, and **Additional Time Zone**, plus a Time Zone Settings link. The observed on/off values are account preferences, not factory defaults; switches were not changed.

Opening Color displayed Task, Habit and Countdown segments. The Task segment offered **Color By** choices List, Tag and Priority. In the observed List setting, explanatory copy said tasks use their list color with tones adjusted for text clarity; a folder/list tree showed color markers. Color mode was not changed. Style, additional timezone configuration, the other color segments, arrange tasks and subscription flows remain untested.

## Measurements and remaining work

The 2440 × 1330 raster screenshot displayed seven evenly sized week columns after a narrow time-label gutter; other captures may have different scale. No exact color, font, size, minimum width, drag constraint, hover or animation duration has been established. Measure at known display scale and compare window widths; inspect every view's empty/overflow/selected state, alternate count controls, event context menus, editing and move/resize gestures, filtering, external calendar permissions, time-zone and DST behavior, all view-option subdialogs and persistence. Do not infer exact implementation rules from the limited samples.
