# Calendar module

Reference: installed TickTick macOS app, light appearance, 2 November 2026. Calendar was excluded from the original implementation scope; the local-only implementation requested on 8 November is documented below. This opening survey remains the historical reference observation. Displayed dates, events, colors and visible options depend on account settings and data. No existing event was modified; an empty add editor was dismissed without entering content. The previously selected Day view was restored after inspection.

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


## Follow-up evidence — 8 November 2026

Inspected the installed `/Applications/TickTick.app` (8.2.20) through Computer Use and REA resource inspection. Executable SHA-256: `e76d6757e4a1e71fd16814443bb3b02d15d0d547ac69abb67306d8dfa3ee35af`. Findings below supplement the 2 November survey; they do not establish decompiled handler logic.

- Confirmed the seven view choices, all-day strip, hourly grid, current-time line, title/navigation controls and sidebar toggle. The inspected account's Week starts Sunday; Taskovsky honors its own persisted week-start setting instead.
- View Options exposes List/Tag/Priority task colors and completed/checklist/repeat visibility, plus habit, focus, countdown and additional time-zone controls. Observed values are account preferences, not factory defaults.
- Arrange tasks opens a right sidebar with List/Tag/Priority grouping and an All Lists / individual-list scope chooser. Two deliberately undated QA tasks appeared there. A third QA task, scheduled via Today, appeared in the all-day strip and did not appear among undated tasks.
- Pasting `today at 14:00` did not produce a timed task in the tested quick-add path. A drag from Arrange to the hourly grid did not produce a confirmed schedule change. Exact drag anchoring, snapping, default duration, cross-day constraints and resize behavior remain **unverified in TickTick**.
- The temporary `Taskovsky Calendar QA` list and its three tasks were archived recoverably after inspection. Original All/Today counts returned to 194/14 and the QA all-day bar disappeared. Restored the initial Day view, closed Arrange and restored its All Lists scope. No pre-existing task was edited.

### REA resource provenance

REA MCP's pre-existing native session reported cleanup pending after an earlier Hopper timeout, and its plist operation returned target-unavailable. Static resource evidence was collected with the installed REA 6.7.0 public CLI instead, without launching a native disassembler or changing REA configuration. A [compact resource extract](evidence/calendar-resource-summary.json) retains the selected outlets, actions, source hashes and limitations in the repository. Raw evidence is under the ignored `build/verification/calendar/` directory; IDs and hashes below make the inspected scope explicit.

| Evidence | Scope and finding |
| --- | --- |
| `ev_fc67899dfdd7aabe3be6073d5dd180bd3821f355ac378bafe8b955f146b29e55` | English `Localizable.strings`, `ticktick-localization-rea.json`. Year heatmap copy describes item quantities; Calendar subscription and split-view/drag labels establish reference surfaces, not behavior algorithms. |
| `ev_cf24ccbdf948aa8b77bf3986062b6fb5b0b383b2fe2b6bd791c6e4c378e242d4` | `ticktick-calendar-ui-rea.json`: selected-resource staging bundle containing the original executable and 40 Calendar/TTCal nibs, 3,675 decoded nodes and 1,769 edges, result not truncated. `resource-manifest.json` records original/staged hashes. This is a resource subset, not a complete application inventory. |
| `TTCalendarViewController.nib` SHA-256 `8aa8d501ef1fc5690001cebeeb67c31eeaaf46759e85e1e01a61651668d77d9b` | Add/sidebar buttons, left/right sidebar containers, month title, previous/next/today/type/more outlets; `sidebarButtonClicked:` connection. |
| `TTCalendarArrangeViewController.nib` SHA-256 `24abbf1ff31de9cbd5ce27d2021b95ba464b26a2a98ada7c6f94051e634e7044` | Outline, segmented control, type/filter/close outlets; close/filter/arrange-type selectors. |
| Display-options nib SHA-256 `56f643612916eb4975c1361e388402f7225da43ce7dd7389a254744f139b9c28` | Completed/checklist/cycles/color/style/weekend/time-zone/habit/focus/countdown controls; switch/time-zone settings selectors. |
| Sidebar nib SHA-256 `47f65893ad48eafd51e1697b20f983765d5a6d93fc9c871c5a9f1b3e545afc24` | Mini-calendar, month navigation and Today selectors. |
| Item-style nib SHA-256 `79e236c18fbd2885f425dadc8a6e6d4099155a83aba9b2d92cf0691938e9ce48` | Classic/modern/standard/heatmap/item-icon selectors. Taskovsky's filled/outline styles are independent choices. |

An initial full-bundle decode stopped at its 64-document limit before the Calendar nibs; it is not used as Calendar coverage. Nib outlets and action selectors corroborate UI structure only. No native handler implementation, runtime scheduling algorithm or original source code was recovered.

## Local Taskovsky Calendar — 8 November 2026

The rail Calendar button opens a module using the existing workspace tasks; no separate event database is introduced. Implementation lives in `TaskCalendarWorkspace.swift`, `CalendarViews.swift`, `CalendarPanels.swift`, `TaskCalendar.swift`, `TaskCalendarProjection.swift` and `CalendarScheduling.swift`.

| Area | Local behavior / deliberate policy |
| --- | --- |
| Views | Day, Week, Month (4–6 rows), Year with quantity heatmap, Agenda (30 days from focus), Multi-Day (2–14 days, default 5), Multi-Week (2–6 weeks, default 2). Year date selection returns to the previous detailed mode. Previous/Today/next and a month/date picker navigate. |
| Sidebar / filters | Mini-month shows item dots and visible range. Inbox/list checkboxes and any selected tag including descendants narrow tasks. Calendar scope is independent of Show in Smart List; archived and deleted tasks stay hidden. Compact windows use overlays and horizontal grid scrolling. |
| Content / display | All-day strip, 24-hour wall-clock grid, current-time line, overlap lanes, month overflow sheet, agenda date groups and year heatmap. List/first-tag/priority colors; filled or outline cards; completed/Won't Do history, inherited checklist rows and repeat preview switches. Notes open in the existing task detail window. |
| Create | Header +, date-cell +, hourly double-click or range drag open a staged task editor; Cancel creates nothing. Save creates one dated task in the chosen list. Non-hourly defaults are all day; hourly header defaults to 09:00–09:30. |
| Arrange | Undated tasks, optionally overdue tasks, grouped by list/first tag/priority; own list chooser within the Calendar scope. Native drag payloads schedule on the grid/date/all-day strip. Each row also has an accessible Schedule button. |
| Move / resize | Native drop onto an hourly column sets the start at the pointer; all-day strip converts to all day; month drop keeps an existing timed task's clock. Timed bottom handle resizes the end. Grid snap is 15 minutes; new timed blocks default to the configured duration or 30 minutes, existing timed windows preserve elapsed duration, point tasks stay point tasks when moved. Exact TickTick rules were not recovered. |
| Editing / undo | Card context menu Schedule… opens precise start/end editing. Remove date also clears repetition and reminders. One atomic schedule operation is used for drag, resize and editor saves. Undo schedule restores only scheduling fields, including manual reminders and nominal recurrence anchors; later schedule/status changes invalidate the token and text/tag/list edits survive. This is an explicit button, not a claim of native Cmd-Z integration. |
| Recurrence | Read-only future cycles share the existing recurrence engine, including nominal cadence, series count and end bounds. Completion-based forecasts assume on-time completion. Projected/checklist rows cannot be moved independently. Per-task traversal caps at 5,000 occurrences and surfaces a notice if reached. No preview records are persisted. |
| Dates / time zones | Timed dates are absolute instants; all-day dates float by civil date in the task's zone, with stored inclusive span ends converted to exclusive display ends. DST grid positions use wall hours; missing times advance to the next valid time and repeated times select the first occurrence. Additional ruler uses local Foundation time-zone data. |

### Remaining local differences and limits

No pixel-perfect style claim is made. Multi-day tasks appear as per-day fragments, rather than one continuous spanning bar. The all-day strip scrolls when crowded and month cells expose hidden entries through +N more in a contained day-details sheet. View Options also uses a contained sheet with Done/Escape dismissal. No all-day resize handle is provided; Schedule… edits the span. No event-style repeating-series exception editor or independent checklist scheduling is introduced. There is no native Calendar-specific Cmd-Z/redo stack, selected-date persistence across launch, drag auto-scroll, keyboard shortcut parity or verified TickTick-style gesture anchoring. Year heatmap intensity is Taskovsky's own count scale. Habit/focus/countdown overlays belong to deferred modules. External integrations are **deliberately deferred**, with the full decision table in [the parity document](taskovsky-parity.md#calendar-integrations-deliberately-deferred--8-november-2026).


### Verification status — 8 November 2026

- Full local suite: **453 passed** (419 XCTest + 34 Swift Testing), including 18 Calendar cases. Calendar cases were rerun after the UI review fixes and passed. Coverage includes all seven date ranges, week starts/leap years, settings compatibility, list/archive/tag scope, all-day civil dates across zones, nominal repeat cadence/counts and traversal bounds, overlap lanes and midnight exclusivity, DST clock placement, reminder shifts/re-anchoring, saved/reloaded schedules, resize minima, invalid ranges and guarded Undo.
- Final release build succeeded without compiler warnings; `codesign --verify --deep --strict build/Taskovsky.app` succeeded. Logs and binary digest are in `build/verification/calendar/`.
- A separate, locally signed `Taskovsky Calendar QA.app` with its own bundle ID was launched using explicit `/private/tmp/TaskovskyCalendarQA-1108/workspace.json` and `settings.json` arguments. The real Taskovsky workspace was not used. `scripts/seed-calendar-qa.py` reproduces a fresh fixture with overlaps, a point task, three-day span, repeat, history, notes, undated tasks and archive/exclusion cases.
- Live Computer Use resumed after the user unlocked the Mac. The table below records observed outcomes; earlier locked attempts are not counted as checks. Release UI was used for the main workflows; the final debug build from the same source used the existing 780-point window command for compact-layout checks because native window-edge drags were unreliable. No debug sizing command was added for Calendar.

| Live check | Observed outcome |
| --- | --- |
| Initial Day layout | Overlap A at 09:00–10:30 and B at 09:30–11:00 occupied separate lanes; the three-day span and note appeared in the all-day strip. Archived/deleted tasks were absent; a smart-list-excluded task remained visible. |
| Create / cancel | Cancelled `Calendar UI cancelled` left no record. Saved `Calendar UI saved` appeared at 09:00–09:30 in Inbox; `Calendar UI all day` appeared on 8 November with no time. Both records persisted in the disposable workspace. A grid range drag opened a staged timed draft; it was cancelled. |
| Timed resize / Undo | Dragging A's bottom handle changed the end from 10:30 to 11:30. Undo schedule restored 09:00–10:30. |
| Timed move / Undo | Dragging A to the hourly grid changed it to 13:00–14:30, preserving its 90-minute duration. Undo restored the original range. |
| Arrange | Undated tasks appeared in List groups. Schedule button opened a 09:00–09:30 editor; Save removed the task from Arrange and added a timed block, and Undo restored its undated state. A later native Arrange drop produced an all-day task and Undo restored it. A dedicated drag handle was added after initial row-drag attempts were unreliable. |
| Precise edit / remove date | Card Schedule… opened the existing all-day range. Remove date hid the task from Calendar; Undo restored it. Clicking the card opened the existing Task Details window with the correct title. |
| Seven views / navigation | Day, Week, Month, Year, Agenda, six-day Multi-Day and two-week Multi-Week were visibly reached. Week used Monday start; Year showed twelve months and quantity fills. Choosing 8 November in Year returned to Month. Next moved Day to Monday 9 November; Today restored Sunday 8 November. |
| Scope | Selecting parent tag Area showed the task tagged with child Project. Clearing tags and hiding Calendar Work removed that list's tasks while preserving Inbox/other-list tasks. All lists restored the scope. |
| Preferences / reload | Priority colors, Outline style, Show Completed off, Show All Repeat Cycles off, six-day count and America/New_York were set in the UI and survived process termination/relaunch. Hourly view showed labeled EST and GMT+3 rulers. |
| Compact layout / sheets | Existing debug command set a 780-point window (718 points for Calendar): two-row header, hidden docked sidebar, usable time grid, and sidebar overlay were observed. The final View Options sheet exposed every control and Done. The +7 more day-details sheet exposed all nine visible items and Done. Restored the wide window afterward. |
| Cleanup / isolation | Cancelled the extra draft generated during a failed window-edge drag. Closed the QA app and confirmed its disappearance from the running-app inventory. QA records remain only in `/private/tmp/TaskovskyCalendarQA-1108`; no real Taskovsky data was used. |

Native automation had inconsistent drag coordinates/sessions in later attempts. Arrange-to-hourly dropping, cross-column dragging, drag auto-scroll, all-day multi-day moves, checklist interactions and the exact 382-point minimum were not independently verified live. Arrange's Schedule button and the shared scheduling model are covered; this table does not claim exhaustive gesture or keyboard parity. The 780-point compact check used a debug build; the signed release build and primary workflows were checked separately.


## PR #2 review corrections — 8 November 2026

The four findings in [the review report](../pr-2-calendar-review-findings-2026-11-08.md#resolutions--8-november-2026) were confirmed and fixed. Existing Schedule… drafts retain point/range shape and exact endpoints; unchanged Save performs no mutation, and Duration explicitly converts a point to a range. Moving an existing range preserves exact elapsed duration even below 15 minutes or at zero. Only visual hit areas, new block defaults and explicit resize use their separate minimum policies. Projected checklist items reset to unchecked, matching real successors, while current checklist visibility keeps its existing behavior. Arrange classifies all-day overdue tasks by the same civil due/end date used in Calendar, while timed tasks remain absolute.

The full suite now passes **464 tests** (430 XCTest + 34 Swift Testing), including 11 new regressions. Release build and code-signature verification pass. Isolated live checks confirmed unchanged point/short/zero saves with byte-identical persistence, explicit duration conversion/Undo, preview checklist visibility and Tokyo civil-date Arrange classification. Native short-block drops remained unconfirmed through Computer Use; production store tests verify exact short-window movement, reminder offsets, reload and Undo. See the review's resolution section for precise evidence and limits. External integration deferrals are unchanged.

## Display-gap follow-up — 8 November 2026

The [detailed gap investigation](../calendar-gap-investigation-2026-11-08.md) extends the merged Calendar baseline. It distinguishes runtime observations, static controls, local interpretations and unknowns. The executable digest still matches the reference above. Current hashes also match the retained time-zone and style nib evidence. [REA session diagnostics](evidence/calendar-gap-session-summary.json) record the unavailable Hopper bridge and unknown lease ownership; no native handler analysis or forced recovery was performed.

TickTick runtime confirmed an additional New York zone with a saved custom NYC label and a ruler eight hours behind Moscow, plus the ability to stage another row. Time-zone configuration's maximum, reorder/emoji behavior and Cancel semantics remain unverified. Static time-zone settings nib controls corroborate add/save/cancel/delete/label/zone surfaces. The style nib exposes Standard/Heatmap and Show Item Icon controls; their exact runtime behavior was not established. No weekend control was visible in the inspected Day/Week options despite its presence in resources.

### Added local behavior

- Up to three named secondary time zones, with searchable city/region selection, editable labels, replacement, explicit order/removal buttons and staged Save/Cancel. The three-row limit and 32-character label limit are deliberate Taskovsky policies. The independent visibility switch preserves configured rows. Current-zone duplicates remain configured but their extra ruler is hidden.
- Day, Week and Multi-Day render these rulers in saved order using Foundation's installed zone data. Header labels fall back to date-specific abbreviations; hour hover text includes the date in that zone. Multi-day rulers use the first displayed date, so a later DST change within the range can have a different offset. No scheduling field or primary-zone setting is changed.
- Legacy single-zone preferences migrate to an enabled row. New keys take precedence even for an empty collection. Invalid/duplicate IDs are discarded, and hidden configurations survive persistence.
- Year offers Standard (item dots) and Heatmap (existing count shading). The previous heatmap default and date drill-down are preserved. Card Filled/Outline style remains separate. These rendering choices are local interpretations, not verified TickTick pixel parity.
- Show Item Icons hides leading task/note/repeat/checklist icons across entry cards. Tasks retain Complete/Reopen in the card context menu. Projection, counts, dates and completion state do not depend on this switch. The options sheet scrolls while keeping Done available.

### Final verification

Full suite: **471 passed** (437 XCTest + 34 Swift Testing), including seven new preference regressions. Release build and `codesign --verify --deep --strict build/Taskovsky.app` pass. Final release executable SHA-256: `ef3346eb5cccc2a36a55aa4f540569a3b9433cf9d3a88fb0d5135bcee57669c4`. Ignored logs: `build/verification/calendar-gap-tests.log` and `calendar-gap-build.log`.

Live checks used the signed release in a separate `local.taskovsky.calendar-display-qa` app with explicit disposable workspace/settings paths under `/private/tmp/TaskovskyCalendarDisplayQA-1108`.

| Check | Observed result |
| --- | --- |
| Search / choose | Search New York, Tokyo and London narrowed results. The final picker supports single-click row selection and Choose/Return. An interfering double-click gesture found during QA was removed. |
| Labels / order / limit | Saved Tokyo and NYC labels appeared before GMT+3 in the chosen order. Tokyo led Moscow by six hours and NYC lagged by eight. A third London ruler appeared; Add was disabled at three. |
| Save / Cancel / remove | Removing NYC then Cancel preserved it on reopening. Saving a London removal removed that ruler and retained Tokyo/NYC. |
| Visibility / reload | Off hid both extra rulers; On restored labels/order. Configuration, icon visibility and Year style persisted in settings and were present after process relaunch. |
| Icons / completion | Icons and checkbox buttons disappeared while task titles and schedule editors remained. The context menu completed and reopened the disposable non-repeating overlap task. |
| Year | Standard visibly used dots; Heatmap restored shading. Each showed its matching legend. Selecting 8 November returned to the previous Day detail mode. |
| Isolation / shutdown | The fixture retained 12 tasks; all due dates, duration windows, zones, recurrence/reminder fields and occurrence indices matched a fresh seed after the checks. The QA app was closed and its running-app state became false. No production Taskovsky workspace was used. |

Exact compact-window layout with three rulers, cross-column DST rulers, TickTick style rendering, weekend availability, working-hour handles, gesture anchoring and the earlier unverified drag paths remain outside these checks. Continuous all-day bars, independent checklist scheduling, series exceptions and native Calendar undo/shortcut parity remain open local differences. External integrations remain deliberately deferred in the existing parity decision table.

Reference cleanup: Day mode, hidden sidebar, current date and original window size were restored through Computer Use. Automation could not reach the temporary New York/NYC ruler's delete control. The user subsequently replied “Restored” to the request to remove that extra row and leave Moscow, completing cleanup by user confirmation. The final time-zone state was not independently re-inspected. No pre-existing TickTick task was edited.
