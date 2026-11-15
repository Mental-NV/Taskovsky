# Mobile visual parity tracker

Updated: **2026-11-15**. Assessment baseline: main `0cbe459` (includes PR115 and scope PR117; excludes pending PR116). **General similarity, not pixel certification.**

This tracks all **46 original observed states**: 15 Calendar, 14 detail/scheduling, 17 Tasks. **10 broadly similar, 34 partial, 2 explicitly deferred.** None is certified pixel-perfect. A counterpart existing does not mean its layout or behavior is complete.

## How to read and maintain

- **Similar**: the general purpose and structure are present, with explicit remaining differences. Not “finished.”
- **Partial**: a counterpart exists but a significant layout, navigation or control gap remains.
- **Deferred**: outside current core completion gates by user direction.
- **Screenshot missing** means no inspected publishable asset attached here, not that the feature is absent.
- These are provisional assessments from merged feature receipts/source and the live reference inventory, not a fresh matched audit of every state.
- **Wide-first:** prioritize major missing structures across core forms before fine pixel polishing. Preserve existing accessibility support; accessibility-specific layouts, Dark and persistence polishing are deferred.
- For each completed UI PR, update affected row, remaining gap, PR/receipt and actual screenshot. Record the captured build; do not label an old screenshot as current. Only compare matched fixture, viewport, theme and text size before upgrading visual acceptance.

## Evidence coverage and limits

**8/46 states have an attached Taskovsky screenshot; 38/46 await one. 0/46 have a portable TickTick reference image attached here.** All eight assets are unmodified, pixel-inspected owned Simulator QA captures with neutral sample content or settings. They are historical feature-checkpoint images, **not a new capture of baseline main**. C04 in particular predates subsequent Calendar layout changes.

The real TickTick images from the original audit remain in its Computer Use trace, not as durable publishable PNGs. See the [reference inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md) for observed hierarchy and trace locators. Do not infer visual equality from a missing reference image. Future reference attachments require a matched safe fixture and privacy review; no personal task/account screenshots are published here.

The [prioritized implementation plan](changes/mobile-live-parity-plan-2026-11-14.md) remains the work queue. Additional known modes outside the original 46 must be tracked separately rather than silently changing this denominator.

## Calendar

| ID | Form / state | General similarity | Biggest remaining gap | Taskovsky evidence | TickTick evidence |
|---|---|---|---|---|---|
| C01 | Hourly Week | Partial | Header, density, overlaps and gestures still need matched comparison. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C02 | Calendar mode menu | Similar | Core chooser and 3 Day exist; naming and order still differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C03 | Week overview | Similar | Mini-month, seven tiles and Day/Back implemented; geometry remains approximate. | [Screenshot](#evidence-c03) · PR112 | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C04 | Calendar overflow menu | Partial | Core routes exist; subscriptions excluded and Share/Print deferred. | [Screenshot](#evidence-c04) · PR103 | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C05 | Filter View Range | Partial | Source/tag filters exist; hierarchy, layout and option inventory differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C06 | View Options | Partial | Nested Color/Style exist; remaining settings structure differs. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C07 | Color settings | Partial | List/tag/priority/custom colors work; source lists use another level. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C08 | Color By menu | Similar | List, Tag and Priority choices exist; matched visual acceptance pending. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C09 | Color Pick/palette | Partial | System picker, not reference named palette families. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C10 | Style | Partial | Filled/Outline instead of Modern/Classic preview tiles; heatmap presentation differs. | [Screenshot](#evidence-c10) · PR115 | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C11 | Show Item Icons | Partial | Task/note/master controls, not full Task/Calendar/Note/Focus inventory. | [Screenshot](#evidence-c11) · PR115 | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C12 | Time Zone Settings | Partial | Primary/additional rulers exist; page structure differs. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C13 | Arrange Tasks panel | Similar | Right panel, grouping, exposed grid and footer implemented; visual tuning remains. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C14 | Arrange overflow | Partial | Overdue option exists; Undated/Notes/Hierarchy do not fully match. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| C15 | Arrange Filter | Similar | Centered staged multi-source/folders/Cancel/Done; session-only persistence, constraints qualified. | [Screenshot](#evidence-c15) · PR113 | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |

## Task detail and scheduling

| ID | Form / state | General similarity | Biggest remaining gap | Taskovsky evidence | TickTick evidence |
|---|---|---|---|---|---|
| D01 | Task detail | Partial | Fields and contextual progress exist; description and metadata arrangement differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D02 | Actions sheet | Partial | Local actions exist; icon strip, order and external actions differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D03 | Actions More | Partial | Actions/customization counterparts exist; inventory and nested structure differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D04 | Tags picker | Partial | Search, selection and save exist; no separate assigned checked section. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D05 | Priority popup | Partial | Choices live in metadata sheet, not matching anchored popup. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D06 | Move to list | Partial | Flat Inbox/list selection; search, folder hierarchy and Add List layout differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D07 | Schedule Date | Partial | Tabs and month grid implemented; outer and nested presentation still differ. | [Screenshot](#evidence-d07) · PR114 | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D08 | Duration | Partial | Start/End, all-day and range move work; summaries and conversion behavior not matched. | [Screenshot](#evidence-d08) · PR114 | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D09 | Time wheel | Partial | Current controls do not match compact wheel popup. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D10 | Reminder menu | Partial | Preset and menu arrangement differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D11 | Custom Reminder | Partial | Date/time alternative, not Day/Week offset wheels. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D12 | Repeat menu | Partial | Simple/custom recurrence exists; labels, presentation and summaries differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D13 | Custom Repeat | Partial | Rich recurrence exists; form differs from wheel/chip layout. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| D14 | Repeat Type | Partial | Anchors and explicit pattern are separate, not combined reference menu. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |

## Tasks and organization

| ID | Form / state | General similarity | Biggest remaining gap | Taskovsky evidence | TickTick evidence |
|---|---|---|---|---|---|
| T01 | Today / List | Similar | Grouped compact rows implemented; header, icons and row details remain. | [Screenshot](#evidence-t01) · PR102 | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T02 | Tasks overflow | Partial | Organization and display toggles differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T03 | List / Kanban submenu | Similar | Both modes exist; extra Timeline and visual details differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T04 | Group & Sort | Partial | Supported subset; choices, direction and reset incomplete. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T05 | Share / Print | Deferred | Explicitly deferred until core features are finished. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T06 | Background chooser | Deferred | Explicitly deferred until core features are finished. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T07 | Tasks drawer | Similar | Indigo navigation implemented; account, utilities and hierarchy differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T08 | Drawer Add | Similar | List/filter/tag routes exist; popup options differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T09 | Smart Lists management | Partial | Visibility management exists; combined layout differs. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T10 | Smart-list visibility popup | Similar | Show / Show if not empty / Hidden choices exist; visual match pending. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T11 | Management Tags tab | Partial | Separate tag management, not matching tab. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T12 | Add List | Partial | Fields exist; matching previews and More layout absent. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T13 | Normal Filter | Partial | Criteria, keywords, type and preview exist; subforms and layout differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T14 | Advanced Filter | Partial | Logic and criteria exist; examples and layout differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T15 | Add Tag | Partial | Name/color/parent exist via different system controls. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T16 | Parent Tag | Partial | Selection exists, not matching pushed radio-list. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |
| T17 | Quick-add composer | Partial | Creation works; low composer, keyboard and toolbar layout differ. | Screenshot missing | [Observed inventory](ticktick-spec/mobile-surface-inventory-2026-11-14.md); image missing |

## Screenshot gallery

Click an image for original resolution. [Machine-readable provenance and SHA-256 manifest](assets/mobile-parity/2026-11-15/manifest.json). Capture runtime metadata is limited to what the linked QA receipt records; no unrecorded device, build or scale is inferred.

<a id="evidence-c03"></a>

### C03: Week overview

Historical [PR #112](https://github.com/Mental-NV/Taskovsky/pull/112) QA capture; [verification receipt](changes/mobile-week-overview-2026-11-15.md). 1170 × 2532 pixels.

[<img src="assets/mobile-parity/2026-11-15/c03-week-overview.png" width="250" alt="Taskovsky Simulator QA: Week overview">](assets/mobile-parity/2026-11-15/c03-week-overview.png)

<a id="evidence-c04"></a>

### C04: Calendar overflow menu

Historical [PR #103](https://github.com/Mental-NV/Taskovsky/pull/103) QA capture; [verification receipt](changes/mobile-calendar-header-2026-11-14.md). 1170 × 2532 pixels.

[<img src="assets/mobile-parity/2026-11-15/c04-calendar-overflow.png" width="250" alt="Taskovsky Simulator QA: Calendar overflow menu">](assets/mobile-parity/2026-11-15/c04-calendar-overflow.png)

<a id="evidence-c10"></a>

### C10: Style

Historical [PR #115](https://github.com/Mental-NV/Taskovsky/pull/115) QA capture; [verification receipt](changes/mobile-calendar-options-navigation-2026-11-15.md). 1170 × 2532 pixels.

[<img src="assets/mobile-parity/2026-11-15/c10-calendar-style.png" width="250" alt="Taskovsky Simulator QA: Style">](assets/mobile-parity/2026-11-15/c10-calendar-style.png)

<a id="evidence-c11"></a>

### C11: Show Item Icons

Historical [PR #115](https://github.com/Mental-NV/Taskovsky/pull/115) QA capture; [verification receipt](changes/mobile-calendar-options-navigation-2026-11-15.md). 1170 × 2532 pixels.

[<img src="assets/mobile-parity/2026-11-15/c11-calendar-icons.png" width="250" alt="Taskovsky Simulator QA: Show Item Icons">](assets/mobile-parity/2026-11-15/c11-calendar-icons.png)

<a id="evidence-c15"></a>

### C15: Arrange Filter

Historical [PR #113](https://github.com/Mental-NV/Taskovsky/pull/113) QA capture; [verification receipt](changes/mobile-arrange-filter-2026-11-15.md). 1170 × 2532 pixels.

[<img src="assets/mobile-parity/2026-11-15/c15-arrange-filter.png" width="250" alt="Taskovsky Simulator QA: Arrange Filter">](assets/mobile-parity/2026-11-15/c15-arrange-filter.png)

<a id="evidence-d07"></a>

### D07: Schedule Date

Historical [PR #114](https://github.com/Mental-NV/Taskovsky/pull/114) QA capture; [verification receipt](changes/mobile-schedule-tabs-2026-11-15.md). 1170 × 2532 pixels.

[<img src="assets/mobile-parity/2026-11-15/d07-schedule-date.png" width="250" alt="Taskovsky Simulator QA: Schedule Date">](assets/mobile-parity/2026-11-15/d07-schedule-date.png)

<a id="evidence-d08"></a>

### D08: Duration

Historical [PR #114](https://github.com/Mental-NV/Taskovsky/pull/114) QA capture; [verification receipt](changes/mobile-schedule-tabs-2026-11-15.md). 1170 × 2532 pixels.

[<img src="assets/mobile-parity/2026-11-15/d08-schedule-duration.png" width="250" alt="Taskovsky Simulator QA: Duration">](assets/mobile-parity/2026-11-15/d08-schedule-duration.png)

<a id="evidence-t01"></a>

### T01: Today / List

Historical [PR #102](https://github.com/Mental-NV/Taskovsky/pull/102) QA capture; [verification receipt](changes/mobile-list-row-density-2026-11-14.md). 1170 × 2532 pixels.

[<img src="assets/mobile-parity/2026-11-15/t01-today-list.png" width="250" alt="Taskovsky Simulator QA: Today / List">](assets/mobile-parity/2026-11-15/t01-today-list.png)

