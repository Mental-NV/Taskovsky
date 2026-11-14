# TickTick mobile surface inventory — November 14, 2026

Status: **Partial live reference inventory; not exhaustive behavior or pixel acceptance.**

Companion to the [prioritized mobile parity plan](../changes/mobile-live-parity-plan-2026-11-14.md). Reference: iPhone 13 Pro, iOS 27.2.1 through user-approved iPhone Mirroring captures; app version/text size/viewport scale not recorded. Observation session `01a1dbc1-2246-72e0-bd3a-9864203a614b` in existing Taskovsky Codex chat, with three states from `01a1dbb8-f07b-7052-ba00-cfb5dc6c8ae3`. Screenshot evidence remains in those Computer Use traces; the clock ranges below are reference locators, not calibrated timestamps or portable image links. No private task titles or personal images are copied to the repository.

Visible labels are evidence, not authorization to implement external services or mutate data. Light-theme Tasks/Calendar scope remains; notification authorization, external integrations, sync, persistence polishing and Dark parity are deferred. This docs-only inventory does not verify current Taskovsky UI or change its behavior. Record matched sanitized screenshot assets before claiming pixel parity. Existing live observation of navigation must not be generalized to untested selection/persistence semantics.

I mapped **46 TickTick iPhone surface states** through iPhone Mirroring: 15 in Calendar, 14 in the task detail and scheduling flow, and 17 in Tasks and organization. Three states are carried forward from the immediately preceding live pass: **Duration**, the **Time** wheel, and the Tasks **View** submenu. The IDs below are stable references. The time ranges identify screenshots in the inspection trace and use the mirrored phone’s clock.

TickTick returned to **Today → Group & Sort**, with **Priority** grouping and **Tag** sorting selected. Calendar stayed in **Week**. I cancelled the schedule and creation drafts without submitting them. No repository files were changed, and Computer Use has stopped.

### Calendar

| ID | Entry and presentation | Visible controls, state, and return behavior |
|---|---|---|
| C01 | Bottom **Calendar** tab → hourly Week | Leading mode icon, centered month, trailing calendar icon and overflow. Weekday/date strip, all-day band, time-zone gutter, hourly grid, and floating **+**. The month label produced no visible change when tapped in the prior pass. |
| C02 | C01 → leading mode icon → anchored menu | **List → Year → Month → Week ✓ → 3 Day → Day**. Backdrop dismissed it. Alternate modes were not selected. |
| C03 | C01 → trailing calendar icon → Week overview | Two columns with a mini-month in the first tile and dated day tiles containing cards. The same header button restored the hourly Week. Individual date jumps were not tested. |
| C04 | C01 → **…** → anchored menu | **Filter View Range → View Options → Arrange Tasks → Calendar Subscription → Share → Print**. The first three opened the surfaces below. |
| C05 | C04 → **Filter View Range** → tall sheet | **All ✓ → Assigned to Me → Tags** with tag rows expanded → **Inbox** → lists and expandable folders. Top-right **✓** returned to Week with the original selection. The inventory covers the visible portion of the source list. |
| C06 | C04 → **View Options** → tall grouped sheet | **Color → Style → Show Details** off → **Show Completed** on → **Show Checklist Item** off → **Show All Repeat Cycles** on → **Show Declined Events** off → **Show Focus Records** off → **Additional Time Zone → Apple Health Data**. Top-right **✓** returned to Week. |
| C07 | C06 → **Color** → pushed page | **Color By** showed **List**. Below were Inbox, lists, and folders with source swatches. Back returned to View Options. |
| C08 | C07 → **Color By** → anchored menu | **List ✓ → Tag → Priority**. Backdrop closed it. The Tag and Priority source layouts remain unverified. |
| C09 | C07 → an existing QA list’s swatch → **Color Pick** | **Recommend → Macaron → Morandi → Rococo → Classic → Memphis → Custom**. The current green swatch was outlined. Back retained the original color. |
| C10 | C06 → **Style** → pushed page | **Item Style** shows previews for **Modern ✓** and **Classic**, then **Show Item Icons**. **Heatmap** shows previews for **Hide** and **Show ✓**. Back returned to View Options. |
| C11 | C10 → **Show Item Icons** → pushed page | **Task → Calendar → Note → Focus Record**, all on. The page says the task checkbox hides when space is limited. That behavior was not exercised. Back returned to Style. |
| C12 | C06 → **Additional Time Zone** → **Time Zone Settings** | **Additional Time Zone** on, **Current Time Zone** showing Moscow GMT+3, and **Add Time Zone**. Back returned to View Options. |
| C13 | C04 → **Arrange Tasks** → right-side panel | **List ✓ → Tag → Priority** above grouped cards. The panel leaves a strip of Week visible. Header **…** and footer **Filter** open separate surfaces. Tapping the exposed grid closed the panel. |
| C14 | C13 → **…** → anchored menu | **Undated Task ✓ → Overdue Task → Show Notes ✓ → Show Task Hierarchy ✓**. Tapping the panel header outside the menu dismissed it. |
| C15 | C13 → **Filter** → centered dialog | **All ✓ → Inbox → lists and nested folder contents**, with **Cancel** and **Done**. Cancel returned to Arrange. This dialog is separate from C05’s tall sheet. |

Calendar screenshot trace: **23:30–23:33**.

### Task detail and scheduling

The detail routes below were exercised from an existing all-day Calendar card. The prior pass also opened details from Today and captured a compact resting sheet for a simple task with no progress row or separate description-edit buttons visible. This inventory does not establish the general rule for showing progress or formatting controls.

| ID | Entry and presentation | Visible controls, state, and return behavior |
|---|---|---|
| D01 | C01 → existing all-day card → rounded bottom detail sheet | Calendar remains visible behind the sheet. Header has **Back**, list selector, flag, and **…**. The sampled task showed schedule, percentage, title, checklist content, tag chip, and lower tag/checklist/attachment icons. Back returned to Week. |
| D02 | D01 → **…** → action sheet | Top icon strip **Pin → Share → Won’t Do → Delete**. Below **Add Subtask → Link Parent Task → Convert to Note → Attachment → Tags → Task Activities → Add to Live Activity → More**. |
| D03 | D02 → **More** → nested sheet | **Comment → Location Reminder → Copy Link → Duplicate → Save as Template → Search → Print**, then **Edit** at the bottom. **×** returned to D02. |
| D04 | D02 → **Tags** → tall picker | **Input Tag** search, assigned tag in its own checked section, and unchecked remaining tags below. **×** returned to detail. |
| D05 | D01 → flag → anchored popup | **High Priority → Medium Priority → Low Priority → No Priority ✓**. Backdrop dismissed it. |
| D06 | D01 → list selector → **Move to** sheet | Search, **Inbox**, current list **✓**, other lists and expandable folders, and **Add List**. **×** returned to detail without moving the task. |
| D07 | D01 → schedule label → **Date / Duration** sheet, **Date** selected | **×**, mode switch, **✓**. Month grid with arrows, selected task date, and separate today marker. **Time → Reminder → Repeat** each showed **None** initially, with **Clear** at the bottom. **×** discarded the outer draft. |
| D08 | D07 → **Duration** | Timed layout showed **Date / Time** summaries, duration, time zone, **All Day** off, **Reminder**, and **Repeat**. Staging **All Day** replaced the summaries with **Start / End** dates. The prior pass cancelled these changes. |
| D09 | D07 → **Time** → compact wheel popup | Hour and minute wheels with time zone below. Opening it staged a time, and closing the popup left the staged value with an inline remove control. Outer **×** discarded it in the prior pass. |
| D10 | D07 → **Reminder** → anchored menu | **None ✓ → On the day → 1 day early → 2 days early → 3 days early → 1 week early → Custom**, then a truncated **Constant Remi…** switch, off. The shown presets used **09:00** for this all-day task. |
| D11 | D10 → **Custom** → centered dialog | **Day / Week**, offset and time wheels, an expired-reminder message for the past task, and **Cancel / Add**. Cancel returned to D10. |
| D12 | D07 → **Repeat** → anchored menu | **None ✓ → Daily → Weekly (Thursday) → Monthly (the 12th day) → Yearly (12 Nov) → Every Weekday (Mon–Fri) → Custom**. The date-specific labels reflect the sampled task. |
| D13 | D12 → **Custom** → tall **Custom Repeat** sheet | **Repeat Type**, **Frequency** interval and unit wheels, a summary, and weekday chips. Initial state was every **1 Week** with **Thu** selected. **×** returned to D12. |
| D14 | D13 → **Repeat Type** → anchored menu | **By Due Dates ✓ → By Completion Date → By Specific Dates**. Backdrop dismissed it with the anchor preserved. |

Detail and scheduling screenshot trace: **23:33–23:35**. D08–D09 are in the previous pass at **23:22**.

### Tasks and organization

| ID | Entry and presentation | Visible controls, state, and return behavior |
|---|---|---|
| T01 | Bottom **Tasks** tab → Today | Leading drawer, trailing lightbulb and **…**, rounded groups with count and disclosure, floating **+**. The sampled group was **No Priority**. |
| T02 | T01 → **…** → anchored menu | **View → Background → Show Details → Show Completed → Hide Checklist Item → Group & Sort → Select → More**. The display toggles were left in their original states. |
| T03 | T02 → **View** → nested menu | **List View ✓ → Kanban View**. Backdrop dismissed it. Kanban was not selected. |
| T04 | T02 → **Group & Sort** → bottom sheet | **Group by:** List, Date, Created Time, Tag, **Priority ✓**, None. **Sort by:** Date, Created Time, Modified Time, Title, **Tag ✓**, Priority. Header showed **Ascending ↑** and footer **Restore default tag order**. Backdrop dismissed it. Direction, reset, and sorting behavior were not exercised. |
| T05 | T02 → **More** → nested menu | **Share → Print**. Backdrop dismissed it. |
| T06 | T02 → **Background** → low bottom panel | **None ✓ → Color → Gradient → Image**. The None panel showed **Follow app theme**. Backdrop dismissed it. |
| T07 | T01 → leading button → indigo left drawer | Identity and utilities at top, then **Today ✓ → Next 7 Days → Inbox → Subscribed Calendars → Tags** with nested tags, followed by lists and folders. Add and management controls sit at the bottom. Backdrop closed it. |
| T08 | T07 → bottom-left add → popup | **List → Filter → Tag**. A backdrop tap dismissed the popup to the drawer. Each blank form was also opened independently. |
| T09 | T07 → bottom-right management → tall sheet, **Smart Lists** selected | **All** hidden, **Today** shown, **Tomorrow** hidden, **Next 7 Days** shown, **Assigned to Me** shown if not empty, **Inbox** shown, **Subscribed Calendars** shown, **Completed** hidden, **Won’t Do** shown if not empty, **Trash** hidden, then **Add Filter**. **✓** returned to drawer. |
| T10 | T09 → Today visibility → anchored popup | **Show ✓ → Show if not empty → Hidden**. Backdrop closed it without a new choice. |
| T11 | T09 → **Tags** tab | Tags visibility showed **Show if not empty**, then **Add Tag** and existing tag rows. I returned to **Smart Lists** before closing management. |
| T12 | T08 → **List** → blank **Add List** sheet | Name with leading icon, **List Color** swatches, and **View Type** previews **List ✓ → Kanban → Timeline** with a badge. Expanding **More** revealed **Folder: None → List Type: Task List → Show in Smart List: All tasks**. The checkmark was disabled with an empty name. **×** cancelled. |
| T13 | T08 → **Filter** → blank editor, **Normal** | Focused blank name. **Filter Conditions** contains **List → Tag → Date → Priority**, all showing **All**, followed by **Include** keywords and **Type: All**. **Preview** is in the footer. The checkmark was disabled. |
| T14 | T13 → **Advanced** tab | Blank **Filter → Logic → Filter** structure, **Add**, **Examples**, and a dimmed **Preview**. **×** cancelled the blank filter. |
| T15 | T08 → **Tag** → blank **Add Tag** sheet | Blank name, **Color** swatches, and **Parent Tag: None**. Disabled checkmark. **×** cancelled. |
| T16 | T15 → **Parent Tag** → pushed picker | **None ✓**, then existing tags with unchecked radio circles. Back returned to the unsaved form. |
| T17 | T01 → floating **+** → low empty composer | **What would you like to do?**, then **Today**, flag, tag, list-style icon, **…**, and microphone. The overflow did not produce a visible menu in this empty state. **Escape** dismissed the composer, and Today’s visible count stayed the same. |

Tasks screenshot trace: **23:35–23:38**. T03 is in the previous pass at **23:24**.

### Remaining coverage

Ten branch groups remain open. This is a count of grouped follow-ups, since menus may vary by destination, card type, and current state.

1. Calendar **List, Year, Month, 3 Day, and Day** screens, date selection from the mini-month, and period navigation.
2. **Filter View Range** below the visible fold, selection rules, and mode-specific options.
3. Calendar color **Tag/Priority** layouts, **Custom** swatch editor, and current/add time-zone pickers.
4. **Arrange** alternate grouping and overdue states, card menus, and drag, move, and resize gestures.
5. Calendar **+** creation, timed and recurring cards, and Calendar event-specific actions.
6. Additional schedule variants, including timed Reminder choices, Duration endpoint editors, Repeat Type variants, and Clear/confirm behavior.
7. Task detail’s rich-description and keyboard controls, progress visibility rules, and nested hierarchy and activity actions.
8. **Kanban**, display toggle behavior, sort direction/reset, selection mode beyond opening, and overflow variants on other destinations.
9. Organization subpickers, filter criteria editors, tag row actions, notification and settings utilities, and existing list/folder context menus.
10. **Background** Color/Gradient/Image, composer routes with entered text, and external or system routes such as subscriptions, Apple Health, sharing, printing, attachments, and microphone.

For near-pixel-perfect parity, capture matching fixtures at the same viewport and text size and compare the **settled** frames. Several sheets changed height after opening. The strongest reusable patterns in this pass are the Calendar header’s anchored menus, View Options’ pushed pages, Arrange’s side panel with its centered Filter dialog, and the schedule sheet’s nested popups with an outer cancel action.

## Implementation handoff and coverage discipline

Prioritize the [plan](../changes/mobile-live-parity-plan-2026-11-14.md): Tasks drawer/shell first (T07–T11), then list density/detail, Calendar header and Arrange (C01–C15), and schedule presentation (D07–D14). Keep each feature PR bounded with independent review, exact-head CI, isolated native interaction tests and matched light-theme screenshots. Do not implement unsupported menu entries as decorative controls. Use the open branches above as evidence requests, not a claim the inventory is complete. Additional inspections should append receipt/state coverage rather than silently changing observed labels.

Docs validation: Markdown/source-link checks and independent review; no runtime tests implied. Workflow filters unchanged. Original worktrees and app fixtures preserved.
