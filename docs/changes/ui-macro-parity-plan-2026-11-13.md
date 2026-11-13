# UI-MAP-001 — Light-theme layout parity work map

Status: **Approved direction; comparison inventory and implementation queue.**

User request (November 13, 2026): compare Tasks left/middle/right, Calendar left/main, and popups/dialogs; prioritize biggest gaps, start implementation, and deliver a screenshot plus a brief gap summary for each completed PR. This replaces ad-hoc UI fixes as the organizing view, not the feature scope.

Baseline inspected: main `3c2db92` (PR66 resize fill, PR67 minimum Outline correction, PR68 light-only scope, PR69 contextual detail controls). Source controls current implementation; reference observations control only the states actually observed. The [feature tracker](../parity-implementation-status.md) remains the feature ledger. This map is the layout work queue, not a competing percentage or a claim that all screens have been measured.

## Scope and evidence rules

- Local Tasks and Calendar only, Mac and separately rendered iPhone; light theme is the active target. Dark parity, external integrations, sync, local-file recovery polish and real notification authorization remain deferred.
- Do not recreate reference account/sync/external-service controls that are outside scope. Mark deliberate omissions rather than treating them as missing UI.
- Record source state, reference state and verification independently: **gap observed**, **candidate**, **integrated**, **reference unknown**, **accepted difference**. Integrated is not synonymous with pixel-equivalent.
- Existing TickTick screenshots may be scaled/lossy. Do not turn raster coordinates into point/font/color constants without calibration. Do not invent cutoff, animation or gesture timing.
- Prior screen-capture denial remains separate from Dark deferral. Do not retry or bypass it. Accessibility inspection can prove named controls/actions but not rendered placement or pixels.

## Macro-area inventory

| Area | Comparison breakdown | Current source / evidence | Next gap or measurement |
| --- | --- | --- | --- |
| **T-L Tasks left panel** | Module rail; smart lists; Lists/folder indentation/disclosure/counts; Filters; Tags; history; separators, hover/selection; independent scrolling | `App.swift`, `WorkspaceSymbols.swift`, `DragReorder.swift`; [workspace](../ticktick-spec/workspace.md), [lists/tags](../ticktick-spec/lists-and-tags.md) | Existing hierarchy and selection are present. Matched current screenshots needed for row pitch, baselines, icons, divider width, scroll behavior and pane widths. No measured whole-panel deficit yet. Excluded module icons intentionally differ. |
| **T-M Tasks middle panel** | Header title/sidebar toggle/sort/more; capture row; sections; task/note rows; hierarchy disclosure; dates/list context; selected/completed states; Board and Timeline; empty/search results | `App.swift`, `QuickEntry.swift`, `TaskRow.swift`, `SearchView.swift`, `TaskTimelineView.swift`; [workspace](../ticktick-spec/workspace.md), [search](../ticktick-spec/search-and-filters.md) | Largest confirmed structural gap: full-search list filter is flat/immediate rather than nested staged tree. Row density/Board geometry need measured comparison, not guessed redesign. Temporary feedback lifetime is being fixed separately. |
| **T-R Tasks right panel** | Completion/date/priority strip; progress; title; description toolbar/content; checklist/subtasks; tags; footer list/more; empty/locked/long-content states | `TaskDetail.swift`, `RichBodyEditor.swift`; [task details guide](https://help.ticktick.com/articles/7055782408586526720), [tasks](../ticktick-spec/tasks.md) | PR69 changes progress/toolbar defaults; source/tests/AX pass, visual hover and placement remain unverified. Orange due-reminder inline card is Taskovsky presentation, not established TickTick parity. Compare density and empty checklist/subtask affordances before changing them. |
| **C-L Calendar left panel** | Mini-month; current/selected date; arrows; Lists/Tags source trees; All/mixed states; collapse; Arrange list; width/scroll | `CalendarPanels.swift`, `CalendarViews.swift`; [Calendar audit](../calendar-visual-parity-audit-2026-11-08.md), [Calendar reference](../ticktick-spec/calendar.md) | Substantial source-filter and header work exists. Recheck exact indentation/spacing and narrow layouts; source state changes must not be inferred from checkbox appearance alone. |
| **C-M Calendar main area** | Header/view chooser/date navigation; Day/Week/Multi-Day hours and rulers; all-day band; Month/Multi-Week overflow; Agenda; Year; cards; selected/current-day/empty states | `CalendarGrid.swift`, `CalendarViews.swift`, `CalendarAppearance.swift`; [Calendar audit](../calendar-visual-parity-audit-2026-11-08.md) | Highest existing visual/interaction cluster: narrow task/note cards and hit targets. PR66/67 merged fill/outline fixes. PR65 and local hit/glyph candidates are not assumed integrated. Exact icon cutoff unknown. Preserve moving/resizing/Undo while measuring. |
| **P-ORG Organization dialogs** | Add/Edit List, Folder, Tag; color/icon picker; view choice; preview; validation; focus; Save/Cancel | `EntitySheet`/`FolderSheet` in `TaskDetail.swift`; [lists/tags](../ticktick-spec/lists-and-tags.md) | **Confirmed high-impact gap:** Add/Edit List has no right-hand live List/Board preview. Existing isolated candidate should be reused, not rewritten. Timeline preview remains an explicit local limitation. |
| **P-SCH Scheduling dialogs** | Date/Duration tabs; mini-calendar; time/time-zone; reminder; repeat/custom recurrence; actions; anchoring/overflow | `ScheduleEditor.swift`, `CustomRecurrenceEditor.swift`; [scheduling](../ticktick-spec/scheduling.md) | Many controls exist. Compare exact layout and keyboard/focus at normal and compact widths; verify Cancel/Done semantics separately. No broad rewrite based on control-count differences. |
| **P-SEARCH Search/filter dialogs** | Quick Search; result grouping/highlights; full-search date/list/tag/status popovers; Normal/Advanced saved filters | `SearchView.swift`, `FilterEditor.swift`; [search](../ticktick-spec/search-and-filters.md) | **Confirmed gap:** list picker needs expandable folder groups, mixed indicators and staged OK/Cancel. Tags staging is separately evidenced; combination semantics remain Taskovsky's documented policy unless observed. |
| **P-CAL Calendar popovers** | View options, sources/colors, Arrange, Jump to Date, overflow/day preview, context menus | `CalendarPanels.swift`, `CalendarTimeZoneSettings.swift`, `CalendarViews.swift` | Compare shared padding/title/action anatomy and clipping; don't let one popover's matching geometry stand for all. |
| **F Feedback and menus** | Success/Undo messages, errors, tooltips, context menus, focus rings | `TaskActionCenter.swift` and feature-local feedback | Current user-reported sticky Schedule updated issue and analogous Mac/iPhone successes are an active separate workstream. Errors must not silently vanish; expiry must not corrupt Undo history. |

## Priority and execution order

Order reflects evidence confidence, affected screen area and existing implementation readiness, not a fabricated severity score.

1. **Finish in-flight user defects:** transient feedback audit/fixes. Keep these separate from layout source ownership.
2. **P-ORG: List editor preview** — reuse/rebase local `LIST-VIS-001` candidate onto current main. Largest bounded, confirmed missing area with ready code. Add actual sheet/focus/Save/Cancel tests; preserve existing form and storage. Publish only honest evidence.
3. **P-SEARCH: staged All Lists tree** — replace flat immediate menu in full Search with draft tree, All/Inbox/folder/list controls and mixed state; OK applies, Cancel/Escape discards. Preserve current query semantics and saved-filter mapping. A separate source-backed change spec precedes implementation.
4. **C-M: compact cards** — consolidate existing candidates rather than add another overlapping experiment. Verify task/note, icons on/off, Filled/Outline, selected/unselected and short/tall duration. Separate visible content from move/resize targets. Do not merge unverified gesture regressions.
5. **T-R: detail layout sweep** — match actual current app (not a stale process) against reference at identical fixture state. Assess title/body/footer spacing and extra empty sections/reminder card; only implement observed or explicitly accepted deltas.
6. **T-L/T-M/C-L: shell and rows** — matched captures at normal/compact widths, then one shared token/component correction per PR. Do not globally change dimensions from the historical two-window samples.
7. **P-SCH/P-CAL and remaining modes** — complete dialog/mode matrix; then regression across all integrated areas.
8. **iPhone mapping** — maintain separate drawer/list/detail and Calendar/popup checklist with supplied iPhone 13 Pro reference. Reuse business behavior, not desktop geometry. Screenshot features do not enlarge desktop-approved scope; reduced editor stays explicit.

## Per-area acceptance matrix

For each area record normal and compact window, empty/populated/long text, selected/hover/focus/disabled/error, expanded/collapsed/scroll overflow, and applicable keyboard/mouse/touch states. Record OS/app versions, exact source revision, fixture identity, view options, appearance, window points, display scale and screenshot pixel size. Compare fonts/baselines, spacing/alignment, colors/borders, icon shape, clipping, hit targets and animation only when evidence exists.

Workflow: reference evidence → small approved delta → implementation/regressions → independent review → native/visual checks → exact-head CI → merge → delivered screenshot/limitations. A blocked visual case remains open, not silently passed by AX or tests. Avoid creating unlimited local candidates behind the same blocked gate.

## Screenshot delivery for completed PRs

User explicitly requested screenshots as deliverables. For each UI PR: one real post-change screenshot (ideally a matched before/after pair), brief caption naming the macro-area/gap, PR link, source/build identity and remaining limits. Use disposable sample data, not personal tasks. Upload approved deliverables through Library and send the attachment in chat. Do not substitute a generated mockup or test-only render as an actual application screenshot. An owned offscreen render may be supplemental only when labeled as such.

If capture remains blocked, say so with the verified implementation result; do not fabricate a screenshot or retry denied permissions. A merged source update is not evidence the user's already-running process loaded it; verify build identity or explain restart requirement.

## This checkpoint

Read source and retained reference documents at `3c2db92`; no fresh TickTick visual inspection or whole-screen measurement. Macro breakdown and priority are evidence-based planning. Active feedback worker owns toast fixes. First new implementation is the existing List preview candidate; native screenshot availability remains an explicit limitation. No overall parity percentage claimed.
