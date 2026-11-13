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

## Current checkpoint — November 13, after PR86

Verified main is `d476267bdffb550de338b08f1b167d78a9949522`. The original inventory/order below records the starting point and must not be read as a list of still-missing implementations. This update is documentation only, not a new visual comparison or native acceptance pass.

| Area | Integrated change | Remaining gate / next action |
| --- | --- | --- |
| F Feedback | PR71/72 bounded iPhone/Mac success-message lifetimes merged. | Preserve persistent errors and Undo behavior; no new feedback defect established here. |
| P-SEARCH / T-M | PR74 hierarchical staged Lists; PR75 staged Tags; PR76/77 custom-date draft and keyboard loop; PR78 week-range captions; PR79 Search All reset; PR82 Normal Date reset; PR83 Priority/Type All resets merged. | Do not implement these again. Functional/native receipts apply only to their recorded states, not whole-panel visual parity. Matched reference geometry remains unverified. |
| P-SCH | PR81 undated Time entry and PR85 coherent Time/Duration state merged. | Latest TickTick AX observation found Time/Reminder/Repeat labels but could not identify Date/Duration/All Day. Those reference transitions remain unknown; no guessed layout or behavior changes. |
| T-R / T-M locked state | PR84 disables embedded checklist edits in Trash; PR86 exposes locked tag chips as read-only. | PR80 observation did not establish reference empty-checklist/subtask entry controls. Do not hide those sections based on AX absence. |
| P-ORG | PR73 List/Board live preview remains draft at `ccbeeb5`. | Actual sheet visual fit remains unverified. Current mergeability check is false; integrate current main and rerun checks only when resuming its acceptance, not as a substitute for it. |
| C-M compact cards | PR66/67 fill and minimum Outline corrections merged; PR65 adaptive checkbox remains draft at `19f805f`. | Option/focus and actual drag/resize gates remain open. Current branch conflicts with main. Recheck source/base, review and exact-head tests after integration; do not erase outstanding native gates. Local hit/glyph candidates are not merged. |
| iPhone Search / filters | PR87 draft at `68f89ee` corrects Any date neutralizing specific rules. Source review, 812 XCTest +38 Swift Testing, Mac release/signature and exact-head hosted CI passed. | Computer Use could not open Simulator interface. No candidate app was installed/launched and no QA fixture created; Codex stopped. Touch/checkmarks/Done/Cancel/reopen remain unverified. Green compilation is not native interaction acceptance. |
| T-L / C-L shell and rows | Existing hierarchy/source-filter implementations remain. | No measured global row/pane geometry defect established. Need supported matched evidence before spacing/token changes. |

### Updated work order

1. Finish the existing PR87 native interaction gate through a supported route when available, without retrying denied capture or changing settings. Keep the draft meanwhile.
2. Resume PR73 and PR65 only with their specific missing acceptance capability; recheck current head/base/conflicts then. Do not accumulate more variants behind the same gate.
3. For new Tasks/Calendar work, prioritize an independently reproducible visible behavior defect or an explicit reference observation. Record evidence before implementation. Do not replace missing evidence with speculative hiding, arbitrary dimensions or new unrelated features.
4. When supported capture becomes available, do the macro-area matched comparison (Tasks left/middle/right, Calendar left/main, dialogs), not merely isolated control screenshots. Retain the per-area matrix below and show the actual post-change screenshot per completed UI PR, or state the limitation.

Dark, description recovery PR61, local-file persistence polishing and real-notification authorization remain deferred. No scope expansion or global parity percentage follows from the merged PR count.

## Original macro-area inventory (historical starting point)

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

## Original priority and execution order (historical)

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

## Original checkpoint

Read source and retained reference documents at `3c2db92`; no fresh TickTick visual inspection or whole-screen measurement. Macro breakdown and priority are evidence-based planning. Active feedback worker owns toast fixes. First new implementation is the existing List preview candidate; native screenshot availability remains an explicit limitation. No overall parity percentage claimed.
