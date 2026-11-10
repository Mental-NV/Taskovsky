# CAL-MOBILE-MONTH-SCROLL-001 — Continuous Full Month browsing on iPhone

Swipe up or down in Full Month to browse adjacent months in one seven-column grid. The top visible week sets the header and Calendar focus. A week spanning two months uses the first day of the newer month. The first day of each month also carries its abbreviated month label in the grid. Each date label exposes its complete local date to accessibility.

The grid projects a rolling 17-week range in the configured calendar and week start. Near either edge it shifts the range around the visible week, retaining that week as the scroll anchor. Previous and Next still jump by calendar month. Today returns to the current month and sets the focus to today. Jump to Date shows the chosen week while retaining the chosen date. A distant jump replaces the buffered range as needed.

The one-, two- and three-week zoom levels retain their bounded views, item capacities and button navigation. Zooming in uses the current focus week. Calendar tasks, filters, Show Details, range bars, drop and capture use the existing projection and scheduling paths. The grid holds position during range selection and endpoint resizing. Returning from a range-capture sheet restores the originating week. Full Month also keeps the visible week through task detail, schedule edits and schedule Undo. Ordinary scrolling writes neither the workspace nor preferences. Relaunch uses the saved mode and resets the date to today.

TickTick's October 31, 2023 notes describe free vertical Month browsing. Its later mobile zoom announcement describes showing fewer weeks and more tasks. The buffer size, header rule and Full Month scope are Taskovsky's design. [TickTick changelog](https://ticktick.com/public/changelog/en.html) · [TickTick What's New](https://help.ticktick.com/articles/7082552170989486080).

[Browse verification](../spec/verification.md#mobile-calendar-month-scroll) · [Schedule and Undo verification](../spec/verification.md#mobile-task-row-swipes).
